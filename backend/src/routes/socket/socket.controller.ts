import { messageChat } from '../../interfaces/messageChat.js';
import Message from '../../models/message.js';
import User from '../../models/user.js';
import logger from '../../utils/logger.js';
import { Request, Response } from 'express';
import * as socketService from './socket.service.js';
import { Types } from 'mongoose';

const ROOM_ERRORS = {
    403: 'Access to this room is forbidden',
    404: 'Room not found',
} as const;

const isStaff = (role?: string) => role === 'admin' || role === 'moderator';

const sendMessage = async (req: Request, res: Response) => {
    try {
        const { roomName, content } = req.body as { roomName?: unknown; content?: unknown };
        const userId = req.user.id;

        const text = typeof content === 'string' ? content.trim() : '';
        if (!text || typeof roomName !== 'string' || !roomName) {
            return res.status(400).json({ error: 'Message content is required' });
        }
        if (text.length > socketService.MAX_MESSAGE_LENGTH) {
            return res.status(400).json({ error: `Message too long (max ${socketService.MAX_MESSAGE_LENGTH} characters)` });
        }

        const user = await User.findById(userId).select('username avatarUrl');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const { room, status } = await socketService.resolveRoomForUser(userId, roomName);
        if (!room) {
            logger.error(`Room ${roomName} inaccessible for user ${userId} (${status})`);
            return res.status(status).json({ error: ROOM_ERRORS[status] });
        }

        const message = new Message({
            content: text,
            user: user,
            room: room,
        });

        await message.save();

        const response: messageChat = {
            content: text,
            createdAt: message.createdAt,
            username: user.username,
            userId: user._id.toString(),
            avatarUrl: user.avatarUrl,
            id: message._id.toString(),
        };

        socketService.sendMessageToRoom(userId, room.name, response);
        socketService.notifyNewMessage(userId, room, response);
        return res.status(201).json({ message: response });
    } catch (err) {
        logger.error('Error in /send:', err);
        return res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
};

const sendAudioMessage = async (req: Request, res: Response) => {
    try {
        const { roomName, duration } = req.body as { roomName: string; duration?: string };
        const userId = req.user.id;

        if (!req.file) {
            return res.status(400).json({ error: 'Audio file is required' });
        }
        if (!roomName) {
            return res.status(400).json({ error: 'Room name is required' });
        }

        const user = await User.findById(userId).select('username avatarUrl');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const { room, status } = await socketService.resolveRoomForUser(userId, roomName);
        if (!room) {
            logger.error(`Room ${roomName} inaccessible for user ${userId} (${status})`);
            return res.status(status).json({ error: ROOM_ERRORS[status] });
        }

        const audioUrl = `uploads/audio/${req.file.filename}`;
        const parsedDuration = duration !== undefined ? Number(duration) : undefined;
        if (parsedDuration !== undefined && (!Number.isFinite(parsedDuration) || parsedDuration < 0)) {
            return res.status(400).json({ error: 'Invalid duration' });
        }
        const message = new Message({
            content: '',
            audioUrl,
            duration: parsedDuration,
            user: user,
            room: room,
        });
        await message.save();

        const response: messageChat = {
            content: '',
            createdAt: message.createdAt,
            username: user.username,
            userId: user._id.toString(),
            avatarUrl: user.avatarUrl,
            id: message._id.toString(),
            audioUrl,
            duration: message.duration,
        };

        socketService.sendMessageToRoom(userId, room.name, response);
        socketService.notifyNewMessage(userId, room, response);
        return res.status(201).json({ message: response });
    } catch (err) {
        logger.error('Error in /send-audio:', err);
        return res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
};

/**
 * Historique d'une room : les 50 messages les plus récents, en ordre
 * chronologique. `before` (date ISO) permet de remonter l'historique.
 */
const getMessages = async (req: Request, res: Response) => {
    try {
        const roomName = req.query.roomName as string;
        if (!roomName) {
            return res.status(400).json({ error: 'Room name is required' });
        }

        let before: Date | undefined;
        if (req.query.before !== undefined) {
            before = new Date(String(req.query.before));
            if (Number.isNaN(before.getTime())) {
                return res.status(400).json({ error: 'Invalid before date' });
            }
        }

        const { room, status } = await socketService.resolveRoomForUser(req.user.id, roomName);
        if (!room) {
            logger.error(`Room ${roomName} inaccessible for user ${req.user.id} (${status})`);
            return res.status(status).json({ error: ROOM_ERRORS[status] });
        }

        const messages = await socketService.getMessagesByRoomId(room._id.toString(), before);
        return res.json({
            messages: messages,
            hasMore: messages.length === socketService.MESSAGES_PAGE_SIZE,
        });
    } catch (err) {
        logger.error('Error in /messages:', err);
        return res.status(500).json({
            error: 'Internal server error',
        });
    }
};

const deleteMessageFromRoom = async (req: Request, res: Response) => {
    try {
        const roomName = req.query.roomName as string;
        const messageId = req.query.messageId as string;

        if (!roomName || !messageId) {
            return res.status(400).json({ error: 'Room name and message ID are required' });
        }

        if (!Types.ObjectId.isValid(messageId)) {
            logger.error('Invalid message ID : ' + messageId);
            return res.status(400).json({ error: 'Invalid message ID' });
        }

        const user = await User.findById(req.user.id);
        if (!user) {
            logger.error('User not found : ' + req.user.id);
            return res.status(404).json({ error: 'An error has occured' });
        }

        const { room, status } = await socketService.resolveRoomForUser(user._id.toString(), roomName);
        if (!room) {
            return res.status(status).json({ error: ROOM_ERRORS[status] });
        }

        const result = await socketService.deleteMessageFromRoom(user._id.toString(), room.name, messageId, {
            roomId: room._id.toString(),
            isStaff: isStaff(user.role),
        });
        if (result === 404) {
            return res.status(404).json({ error: 'Message not found' });
        }
        if (result === 403) {
            return res.status(403).json({ error: 'You can only delete your own messages' });
        }
        return res.json({ message: 'Message deleted' });
    } catch (err) {
        logger.error('Error in /delete-message:', err);
        return res.status(500).json({
            error: 'Internal server error',
        });
    }
};

const deleteAllMessagesFromRoom = async (req: Request, res: Response) => {
    try {
        const roomName = req.query.roomName as string;
        if (!roomName) {
            return res.status(400).json({ error: 'Room name is required' });
        }

        const user = await User.findById(req.user.id);

        if (!user) {
            logger.error('User not found : ' + req.user.id);
            return res.status(404).json({ error: 'An error has occured' });
        }

        const { room, status } = await socketService.resolveRoomForUser(user._id.toString(), roomName);
        if (!room) {
            return res.status(status).json({ error: ROOM_ERRORS[status] });
        }

        // Vider le Global efface les messages de tout le monde : réservé au staff.
        if (room.name === socketService.GLOBAL_ROOM && !isStaff(user.role)) {
            return res.status(403).json({ error: 'Only moderators can clear the global room' });
        }

        await socketService.deleteAllMessagesFromRoom(user._id.toString(), room._id.toString(), room.name);
        return res.json({ message: 'Messages deleted' });
    } catch (err) {
        logger.error('Error in /delete-messages:', err);
        return res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
};

const getConversations = async (req: Request, res: Response) => {
    try {
        const conversations = await socketService.getConversationsSummary(req.user.id);
        return res.json({ conversations });
    } catch (err) {
        logger.error('Error in /conversations:', err);
        return res.status(500).json({ error: 'Internal server error' });
    }
};

export { sendMessage, sendAudioMessage, getMessages, getConversations, deleteMessageFromRoom, deleteAllMessagesFromRoom };
