// routes/message.routes.ts
import { Router, Request, Response } from 'express';
import { Types } from 'mongoose';
import Message, { IMessage } from '../models/message.js';
import Room from '../models/room.js';
import User from '../models/user.js';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import { socketService } from '../services/socket.js';

const router = Router();

router.post('/send', auth, async (req: Request, res: Response) => {
    try {
        const { roomId, content } = req.body;
        const userId = req.user.id;

        if (!content || typeof content !== 'string') {
            return res.status(400).json({ error: 'Message content is required' });
        }

        if (!Types.ObjectId.isValid(roomId)) {
            logger.error('Invalid room ID : ' + roomId);
            return res.status(400).json({ error: 'Invalid room ID' });
        }

        const user = await User.findById(userId).select('username');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // const room = await Room.findById(roomId);
        // if (!room) {
        //     return res.status(404).json({ error: 'Room not found' });
        // }

        const exampleRoom = new Room({
            name: 'Conference Room',
            owner: user, // Replace with a valid user ID
        });

        await exampleRoom.save();

        if (!exampleRoom) throw new Error('Room creation failed');

        console.log(exampleRoom);

        const message = new Message({
            content: content,
            user: user,
            room: exampleRoom,
        });

        await message.save();

        socketService.emitToRoom(roomId, 'receive_message', message);

        res.status(201).json(message);
    } catch (err) {
        logger.error('Error in /send:', err);
        res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
});

router.get('/messages', auth, async (req: Request, res: Response) => {
    try {
        const roomId = req.query.roomId as string;
        if (!Types.ObjectId.isValid(roomId)) {
            return res.status(400).json({ error: 'Invalid room ID' });
        }
        const messages = await getMessagesByRoomId(roomId);
        res.json(messages);
    } catch (err) {
        logger.error('Error in /messages:', err);
        res.status(500).json({
            error: 'Internal server error',
            message: err instanceof Error ? err.message : 'Unknown error',
        });
    }
});

async function getMessagesByRoomId(roomId: string): Promise<IMessage[]> {
    return Message.find({ room: roomId })
        .populate('room')
        .populate('user', 'username')
        .sort({ createdAt: -1 })
        .limit(50);
}

export default router;
