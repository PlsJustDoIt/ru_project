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
        throw new Error('Failed to initialize global room');
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

    // TODO : à finir
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    socket.on('join_room', async (data: any[]) => {
        logger.info('User %s joining room with data %o', socket.id, data);
        logger.info(data);
        try {
            if (!data) {
                throw new Error('data is required');
            }

            if (data.length !== 2) {
                throw new Error('Exactly 2 participants are required, other cases are not supported');
            }

            const participants = data as string[];

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
        throw new Error('Failed to send message to room');
    }
};

const getMessagesByRoomId = async (roomId: string): Promise<MessageResponse[]> => {
    const messages = await Message.find({ room: roomId })
        .populate<{ user: { username: string } }>('user', 'username')
        .sort({ createdAt: 1 })
        .limit(50);

    return messages.map((message) => {
        return {
            content: message.content,
            createdAt: message.createdAt,
            username: message.user.username,
            id: message._id.toString(),
        };
    });
};

const deleteMessageFromRoom = async (userId: string, roomName: string, messageId: string) => {
    try {
        await Message.deleteOne({ _id: messageId });

        socketHandler.emitToRoom(userId, 'receive_delete_message', roomName, { messageId });
        return true;
    } catch (error) {
        logger.error('Error deleting message:', error);
        throw new Error('Failed to delete message');
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
        throw new Error('Failed to delete all messages');
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

export { deleteAllMessagesFromRoom, deleteMessageFromRoom, getMessagesByRoomId, sendMessageToRoom, setupSocketApplicationEvents, initGlobalRoom, createRoom, getUserRooms };
