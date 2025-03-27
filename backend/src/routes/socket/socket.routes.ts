// routes/message.routes.ts
import { Router } from 'express';
import auth from '../../middleware/auth.js';

import { deleteAllMessagesFromRoom, deleteMessageFromRoom, getMessages, sendMessage } from './socket.controller.js';

const router = Router();

router.post('/send-message', auth, sendMessage);

router.get('/messages', auth, getMessages);

router.delete('/delete-all-messages', auth, deleteAllMessagesFromRoom);

router.delete('/delete-message', auth, deleteMessageFromRoom);

export default router;
