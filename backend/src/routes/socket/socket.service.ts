// services/socket.service.ts
import { Socket } from 'socket.io';
import logger from '../../utils/logger.js';
import Room, { IRoom } from '../../models/room.js';
import { messageChat } from '../../interfaces/messageChat.js';
import MessageResponse from '../../interfaces/messageResponse.js';
import Message from '../../models/message.js';
import User from '../../models/user.js';
import { Types } from 'mongoose';
import { socketHandler } from '../../utils/socket.js';

export const GLOBAL_ROOM = 'Global';
/** Nombre de messages renvoyés par page d'historique. */
export const MESSAGES_PAGE_SIZE = 50;
/** Longueur max d'un message texte. */
export const MAX_MESSAGE_LENGTH = 2000;

type PopulatedSender = { _id: Types.ObjectId; username: string; avatarUrl?: string } | null;

// La room globale sert à connecter tous les utilisateurs, et pouvoir faire le lien avec le modèle message
const initGlobalRoom = async () => {
    try {
        const globalRoom = await Room.findOne({ name: GLOBAL_ROOM });
        if (!globalRoom) {
            await Room.create({
                name: GLOBAL_ROOM,
            });
        }
    } catch (error) {
        logger.error('Failed to initialize global room:', error);
        throw new Error('Failed to initialize global room', { cause: error });
    }
};

/** `idA_idB` (ids triés) -> [idA, idB] ; null si ce n'est pas un nom de room privée. */
const parsePrivateRoomName = (roomName: string): [string, string] | null => {
    const parts = roomName.split('_');
    if (parts.length !== 2 || !parts.every(p => Types.ObjectId.isValid(p) && /^[a-f0-9]{24}$/i.test(p))) {
        return null;
    }
    return [parts[0], parts[1]];
};

/** Un utilisateur peut-il lire / écrire dans cette room ? */
const canAccessRoom = (userId: string, room: Pick<IRoom, 'name' | 'participants'>): boolean => {
    if (room.name === GLOBAL_ROOM) return true;
    return (room.participants ?? []).some(p => p.toString() === userId);
};

/** Les deux utilisateurs sont-ils amis ? (condition pour ouvrir une conversation privée) */
const areFriends = async (userId: string, otherId: string): Promise<boolean> => {
    const user = await User.findById(userId).select('friends');
    return !!user?.friends?.some(f => f.toString() === otherId);
};

type RoomResolution = { room: IRoom; status: 200 } | { room: null; status: 403 | 404 };

/**
 * Retrouve la room [roomName] pour [userId] en vérifiant l'accès.
 * Une room privée inexistante est créée à la volée si l'utilisateur en fait
 * partie et que les deux participants sont amis (évite la course avec
 * `join_room` quand on écrit le premier message).
 */
const resolveRoomForUser = async (userId: string, roomName: string): Promise<RoomResolution> => {
    let room = await Room.findOne({ name: roomName });
    if (!room) {
        const participants = parsePrivateRoomName(roomName);
        if (!participants || !participants.includes(userId)) {
            return { room: null, status: 404 };
        }
        const otherId = participants[0] === userId ? participants[1] : participants[0];
        if (!(await areFriends(userId, otherId))) {
            return { room: null, status: 403 };
        }
        room = await getOrCreatePrivateRoom(participants[0], participants[1]);
        if (!room) {
            return { room: null, status: 404 };
        }
    }
    if (!canAccessRoom(userId, room)) {
        return { room: null, status: 403 };
    }
    return { room, status: 200 };
};

function setupSocketApplicationEvents(): void {
    socketHandler.getIO().on('connection', (socket: Socket) => {
        setupSocketEventHandlers(socket);
    });
}

const setupSocketEventHandlers = (socket: Socket) => {
    socket.on('join_global_room', async () => {
        try {
            const globalRoom = await Room.findOne({ name: GLOBAL_ROOM });
            if (!globalRoom) {
                throw new Error('Global room not found');
            }

            logger.info('User %s joining global room %s', socket.id, globalRoom.name);

            await socket.join(globalRoom.name);
            socket.emit('room_joined', { roomName: globalRoom.name });
        } catch (error) {
            logger.error('Error joining global room:', error);
            socket.emit('error', 'Failed to join global room');
        }
    });

    socket.on('join_room', async (data: { participants?: string[] }) => {
        logger.info('User %s joining room with data %o', socket.id, data);
        try {
            if (!data) {
                throw new Error('data is required');
            }

            const participants = data.participants?.map(p => String(p));

            if (!Array.isArray(participants) || participants.length !== 2) {
                throw new Error('Exactly 2 participants are required, other cases are not supported');
            }

            const userId: string = socket.data.userId;
            // On ne peut rejoindre qu'une conversation dont on fait partie.
            if (!participants.includes(userId)) {
                throw new Error('User is not a participant of this room');
            }

            const resolution = await resolveRoomForUser(userId, generatePrivateRoomName(participants[0], participants[1]));
            const room = resolution.room;

            if (!room) {
                throw new Error('Room not found');
            }

            await socket.join(room.name);
            socket.emit('room_joined', { roomName: room.name });
        } catch (error) {
            logger.error('Error joining room:', error);
            socket.emit('error', 'Failed to join room');
        }
    });

    socket.on('leave_room', async (roomName: string) => {
        try {
            if (!roomName) {
                throw new Error('roomName is required');
            }
            await socket.leave(roomName);
            socket.emit('room_left', { roomName });
        } catch (error) {
            logger.error('Error leaving room:', error);
            socket.emit('error', 'Failed to leave room');
        }
    });
    // La déconnexion (présence en ligne) est gérée par SocketHandler.
};

const sendMessageToRoom = (userId: string, roomName: string, message: messageChat) => {
    try {
        socketHandler.emitToRoom(userId, 'receive_message', roomName, { roomName, message });
        return true;
    } catch (error) {
        logger.error('Error sending message to room:', error);
        throw new Error('Failed to send message to room', { cause: error });
    }
};

// Notif in-app : prévient les participants d'un nouveau message, qu'ils aient
// rejoint la room socket ou non (la socket persistante les rend conscients
// partout). Privé -> ciblé sur l'autre participant ; Global -> tous.
const notifyNewMessage = (
    senderId: string,
    room: { name: string; participants?: { toString(): string }[] },
    message: messageChat,
) => {
    const payload = { roomName: room.name, message };
    if (room.name === GLOBAL_ROOM) {
        socketHandler.broadcastToEveryone('notify_message', payload);
        return;
    }
    for (const participant of room.participants ?? []) {
        const participantId = participant.toString();
        if (participantId !== senderId) {
            socketHandler.emitToUser('notify_message', participantId, payload);
        }
    }
};

const toMessageResponse = (message: {
    _id: Types.ObjectId;
    content: string;
    createdAt: Date;
    audioUrl?: string;
    duration?: number;
    user: PopulatedSender;
}): MessageResponse => ({
    content: message.content,
    createdAt: message.createdAt,
    // L'expéditeur peut avoir été supprimé : populate renvoie alors null.
    username: message.user?.username ?? 'Utilisateur supprimé',
    userId: message.user?._id?.toString(),
    avatarUrl: message.user?.avatarUrl,
    id: message._id.toString(),
    audioUrl: message.audioUrl,
    duration: message.duration,
});

/**
 * Renvoie les [MESSAGES_PAGE_SIZE] messages les plus récents de la room (ou
 * ceux antérieurs à [before] pour paginer), en ordre chronologique.
 */
const getMessagesByRoomId = async (roomId: string, before?: Date): Promise<MessageResponse[]> => {
    const filter: Record<string, unknown> = { room: roomId };
    if (before) {
        filter.createdAt = { $lt: before };
    }
    const messages = await Message.find(filter)
        .populate<{ user: PopulatedSender }>('user', 'username avatarUrl')
        .sort({ createdAt: -1 })
        .limit(MESSAGES_PAGE_SIZE);

    // Tri décroissant pour prendre les plus récents, puis remis dans l'ordre.
    return messages.reverse().map(toMessageResponse);
};

// Résumé des conversations de l'utilisateur : Global + ses rooms privées,
// chacune avec son dernier message (ou null si vide).
const getConversationsSummary = async (userId: string) => {
    const rooms = await Room.find({ $or: [{ name: GLOBAL_ROOM }, { participants: userId }] });

    return Promise.all(
        rooms.map(async (room) => {
            const last = await Message.findOne({ room: room._id })
                .populate<{ user: PopulatedSender }>('user', 'username avatarUrl')
                .sort({ createdAt: -1 });

            return {
                roomName: room.name,
                lastMessage: last
                    ? {
                            ...toMessageResponse(last),
                            content: last.audioUrl ? '🎤 Message vocal' : last.content,
                            audioUrl: undefined,
                            duration: undefined,
                        }
                    : null,
            };
        }),
    );
};

/**
 * Supprime un message de la room. Seul son auteur (ou un admin / modérateur)
 * peut le supprimer. Renvoie le code HTTP à renvoyer.
 */
const deleteMessageFromRoom = async (
    userId: string,
    roomName: string,
    messageId: string,
    options: { roomId?: string; isStaff?: boolean } = {},
): Promise<200 | 403 | 404> => {
    try {
        const message = await Message.findById(messageId);
        if (!message || (options.roomId && message.room.toString() !== options.roomId)) {
            return 404;
        }
        if (!options.isStaff && message.user.toString() !== userId) {
            return 403;
        }
        await Message.deleteOne({ _id: messageId });

        socketHandler.emitToRoom(userId, 'receive_delete_message', roomName, { roomName, messageId });
        return 200;
    } catch (error) {
        logger.error('Error deleting message:', error);
        throw new Error('Failed to delete message', { cause: error });
    }
};

const deleteAllMessagesFromRoom = async (userId: string, roomId: string, roomName: string) => {
    try {
        await Message.deleteMany({ room: roomId });
        socketHandler.emitToRoom(userId, 'receive_delete_all_messages', roomName, { roomName });
        return true;
    } catch (error) {
        logger.error('Error deleting all messages:', error);
        throw new Error('Failed to delete all messages', { cause: error });
    }
};

const generatePrivateRoomName = (user1Id: string, user2Id: string) => {
    return [user1Id, user2Id].sort().join('_');
};

// Fonction pour obtenir ou créer une room privée
async function getOrCreatePrivateRoom(user1Id: string, user2Id: string) {
    // Chercher une room existante avec exactement ces deux participants
    const existingRoom = await Room.findOne({
        participants: {
            $all: [user1Id, user2Id],
            $size: 2,
        },
    });

    if (existingRoom) {
        return existingRoom;
    }

    // Créer une nouvelle room si elle n'existe pas
    const roomName = generatePrivateRoomName(user1Id, user2Id);

    return await createRoom({
        name: roomName,
        participants: [user1Id, user2Id],
    });
}

async function createRoom(room: { name: string; participants?: Types.ObjectId[] | string[] }) {
    return await Room.create(room);
}

// Fonction utilitaire pour trouver toutes les rooms privées d'un utilisateur
async function getUserRooms(userId: Types.ObjectId) {
    return await Room.find({
        participants: userId,
    }).populate('participants', 'username avatarUrl status');
}

export {
    deleteAllMessagesFromRoom, deleteMessageFromRoom, getMessagesByRoomId, getConversationsSummary,
    notifyNewMessage, sendMessageToRoom, setupSocketApplicationEvents, initGlobalRoom, createRoom,
    getUserRooms, canAccessRoom, resolveRoomForUser, parsePrivateRoomName, generatePrivateRoomName,
};
