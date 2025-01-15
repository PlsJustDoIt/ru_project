// routes/message.routes.ts
import { Router, Request, Response } from 'express';
import { Types } from 'mongoose';
import Message from '../models/message.js';
import Room from '../models/room.js';
import User from '../models/user.js';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import { socketService } from '../services/socket.js';
import MessageResponse from '../interfaces/messageResponse.js';
import { Socket } from 'socket.io';

const router = Router();

router.post('/send', auth, async (req: Request, res: Response) => {
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
            return res.status(404).json({ error: 'An error has occured' });
        }

        const message = new Message({
            content: content,
            user: user,
            room: room,
        });

        await message.save();

        const response = {
            content: content,
            createdAt: message.createdAt,
            username: user.username,
            id: message._id.toString(),
        };

        console.log(response);

        // socketService.emitToRoom('receive_message', room.id.toString(), { message: response });

        // return res.status(201).json({ message: response });

        const socket: Socket | undefined = socketService.getSocketFromUserId(userId);
        if (socket) {
            socketService.emitToRoomWithSocket(socket, 'receive_message', room._id.toString(), { message: response });
            return res.status(201).json({ message: response });
        }
    } catch (err) {
        logger.error('Error in /send:', err);
        return res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
});

// router.post('/send-chat-room', auth, async (req: Request, res: Response) => {
//     try {
//         const { content } = req.body as { content: string };
//         const userId = req.user.id;

//         if (!content) {
//             return res.status(400).json({ error: 'Message content is required' });
//         }

//         const user = await User.findById(userId).select('username');
//         if (!user) {
//             return res.status(404).json({ error: 'User not found' });
//         }

//         const room = await Room.findOne({ name: 'Global' });
//         if (!room) {
//             return res.status(404).json({ error: 'Room not found' });
//         }

//         const message = new Message({
//             content: content,
//             user: user,
//             room: room,
//         });

//         await message.save();

//         const response = {
//             content: content,
//             createdAt: message.createdAt,
//             username: user.username,
//             id: message._id.toString(),
//         };

//         // socketService.emitToRoom('receive_message', room._id.toString(), { message: response });
//     } catch (err) {
//         logger.error('Error in /send-chat-room:', err);
//         return res.status(500).json({
//             error: 'Internal server error',
//             message: err instanceof Error ? err.message : 'Unknown error',
//         });
//     }
// });

router.get('/messages', auth, async (req: Request, res: Response) => {
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

        const messages = await getMessagesByRoomId(room._id.toString());
        return res.json({ messages: messages });
    } catch (err) {
        logger.error('Error in /messages:', err);
        return res.status(500).json({
            error: 'Internal server error',
        });
    }
});

// router.get('/chat-room', auth, async (req: Request, res: Response) => {
//     try {
//         const chatRoom = await Room.findOne({ name: 'Global' });
//         if (!chatRoom) {
//             return res.status(404).json({ error: 'Chat room not found' });
//         }
//         const messages = await getMessagesByRoomId(chatRoom._id.toString());
//         return res.json({ messages: messages });
//     } catch (err) {
//         logger.error('Error in /chat-room:', err);
//         res.status(500).json({
//             error: 'Internal server error',
//             message: err instanceof Error ? err.message : 'Unknown error',
//         });
//     }
// });

router.delete('/delete-all-messages', auth, async (req: Request, res: Response) => {
    try {
        const roomId = req.query.roomId as string;
        if (!roomId) {
            return res.status(400).json({ error: 'Room ID is required' });
        }

        if (!Types.ObjectId.isValid(roomId)) {
            logger.error('Invalid room ID : ' + roomId);
            return res.status(400).json({ error: 'Invalid room ID' });
        }

        await Message.deleteMany({ room: roomId });

        return res.json({ message: 'Messages deleted' });
    } catch (err) {
        logger.error('Error in /delete-messages:', err);
        return res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
});

router.delete('/delete-message', auth, async (req: Request, res: Response) => {
    try {
        const messageId = req.query.messageId as string;
        if (!messageId) {
            return res.status(400).json({ error: 'Message ID is required' });
        }

        if (!Types.ObjectId.isValid(messageId)) {
            logger.error('Invalid message ID : ' + messageId);
            return res.status(400).json({ error: 'Invalid message ID' });
        }

        await Message.deleteOne({ _id: messageId });

        return res.json({ message: 'Message deleted' });
    } catch (err) {
        logger.error('Error in /delete-message:', err);
        return res.status(500).json({
            error: 'Internal server error',
        });
    }
});

async function getMessagesByRoomId(roomId: string): Promise<MessageResponse[]> {
    const messages = await Message.find({ room: roomId })
        .populate<{ user: { username: string } }>('user', 'username')
        // .populate('room')
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
}

export default router;
