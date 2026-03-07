import { messageChat } from '../../interfaces/messageChat.js';
import Message from '../../models/message.js';
import Room from '../../models/room.js';
import User from '../../models/user.js';
import logger from '../../utils/logger.js';
import { Request, Response } from 'express';
import * as socketService from './socket.service.js';
import { Types } from 'mongoose';

const sendMessage = async (req: Request, res: Response) => {
    try {
        const { roomName, content } = req.body as { roomName: string; content: string };
        const userId = req.user.id;

        if (!content || !roomName) {
            return res.status(400).json({ error: 'Message content is required' });
        }

        const user = await User.findById(userId).select('username');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const room = await Room.findOne({ name: roomName });
        if (!room) {
            logger.error('Room not found : ' + roomName);
            return res.status(404).json({ error: 'Room not found' });
        }

        const message = new Message({
            content: content,
            user: user,
            room: room,
        });

        await message.save();

        const response: messageChat = {
            content: content,
            createdAt: message.createdAt,
            username: user.username,
            id: message._id.toString(),
        };

        socketService.sendMessageToRoom(userId, room.name, response);
        return res.status(201).json({ message: response });
    } catch (err) {
        logger.error('Error in /send:', err);
        return res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
};

const getMessages = async (req: Request, res: Response) => {
    try {
        const roomName = req.query.roomName as string;
        if (!roomName) {
            return res.status(400).json({ error: 'Room name is required' });
        }

        const room = await Room.findOne({ name: roomName });
        if (!room) {
            logger.error('Room not found : ' + roomName);
            return res.status(404).json({ error: 'An error has occured' });
        }

        const messages = await socketService.getMessagesByRoomId(room._id.toString());
        return res.json({ messages: messages });
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

        const room = await Room.findOne({ name: roomName });

        if (!room) {
            logger.error('Room not found : ' + roomName);
            return res.status(404).json({ error: 'Room not found' });
        }

        await socketService.deleteMessageFromRoom(user._id.toString(), room.name, messageId);
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

        const room = await Room.findOne({ name: roomName });

        if (!room) {
            logger.error('Room not found : ' + roomName);
            return res.status(404).json({ error: 'An error has occured' });
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

export { sendMessage, getMessages, deleteMessageFromRoom, deleteAllMessagesFromRoom };
