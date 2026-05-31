// services/socket.service.ts
import { Socket } from 'socket.io';
import logger from '../../utils/logger.js';
import Room from '../../models/room.js';
import { messageChat } from '../../interfaces/messageChat.js';
import MessageResponse from '../../interfaces/messageResponse.js';
import Message from '../../models/message.js';
import { Types } from 'mongoose';
import { socketHandler } from '../../utils/socket.js';

// La room globale sert à connecter tous les utilisateurs, et pouvoir faire le lien avec le modèle message
const initGlobalRoom = async () => {
    try {
        const globalRoom = await Room.findOne({ name: 'Global' });
        if (!globalRoom) {
            await Room.create({
                name: 'Global',
            });
        }
    } catch (error) {
        logger.error('Failed to initialize global room:', error);
        throw new Error('Failed to initialize global room', { cause: error });
    }
};

function setupSocketApplicationEvents(): void {
    socketHandler.getIO().on('connection', (socket: Socket) => {
        setupSocketEventHandlers(socket);
    });
}

const setupSocketEventHandlers = (socket: Socket) => {
    socket.on('join_global_room', async () => {
        try {
            const globalRoom = await Room.findOne({ name: 'Global' });
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

            const participants = data.participants;

            if (!Array.isArray(participants) || participants.length !== 2) {
                throw new Error('Exactly 2 participants are required, other cases are not supported');
            }

            const room = await getOrCreatePrivateRoom(participants[0], participants[1]);

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

    socket.on('disconnect', () => {
        const userId = socket.data.userId;
        logger.info(`User ${userId} disconnected`);

        // Nettoyer la connexion
        socketHandler.removeUserFromConnectedUsers(userId);
        socketHandler.broadcastToEveryone('userOffline', userId);
    });
};

const sendMessageToRoom = (userId: string, roomName: string, message: messageChat) => {
    try {
        socketHandler.emitToRoom(userId, 'receive_message', roomName, { message });
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
    if (room.name === 'Global') {
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

const getMessagesByRoomId = async (roomId: string): Promise<MessageResponse[]> => {
    const messages = await Message.find({ room: roomId })
        .populate<{ user: { username: string } | null }>('user', 'username')
        .sort({ createdAt: 1 })
        .limit(50);

    return messages.map((message) => {
        return {
            content: message.content,
            createdAt: message.createdAt,
            // L'expéditeur peut avoir été supprimé : populate renvoie alors null.
            username: message.user?.username ?? 'Utilisateur supprimé',
            id: message._id.toString(),
            audioUrl: message.audioUrl,
            duration: message.duration,
        };
    });
};

// Résumé des conversations de l'utilisateur : Global + ses rooms privées,
// chacune avec son dernier message (ou null si vide).
const getConversationsSummary = async (userId: string) => {
    const rooms = await Room.find({ $or: [{ name: 'Global' }, { participants: userId }] });

    return Promise.all(
        rooms.map(async (room) => {
            const last = await Message.findOne({ room: room._id })
                .populate<{ user: { username: string } | null }>('user', 'username')
                .sort({ createdAt: -1 });

            return {
                roomName: room.name,
                lastMessage: last
                    ? {
                            content: last.audioUrl ? '🎤 Message vocal' : last.content,
                            createdAt: last.createdAt,
                            username: last.user?.username ?? 'Utilisateur supprimé',
                            id: last._id.toString(),
                        }
                    : null,
            };
        }),
    );
};

const deleteMessageFromRoom = async (userId: string, roomName: string, messageId: string) => {
    try {
        await Message.deleteOne({ _id: messageId });

        socketHandler.emitToRoom(userId, 'receive_delete_message', roomName, { messageId });
        return true;
    } catch (error) {
        logger.error('Error deleting message:', error);
        throw new Error('Failed to delete message', { cause: error });
    }
};

const deleteAllMessagesFromRoom = async (userId: string, roomId: string, roomName: string) => {
    try {
        await Message.deleteMany({ room: roomId });
        const socket: Socket | undefined = socketHandler.getSocketFromUserId(userId);
        if (!socket) {
            throw Error('Socket not found for user : ' + userId);
        }
        socketHandler.emitToRoom(userId, 'receive_delete_all_messages', roomName, {});
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

// isUserOnline
// emitToUser
// initGlobalRoom

export { deleteAllMessagesFromRoom, deleteMessageFromRoom, getMessagesByRoomId, getConversationsSummary, notifyNewMessage, sendMessageToRoom, setupSocketApplicationEvents, initGlobalRoom, createRoom, getUserRooms };
