// routes/message.routes.ts
import { Router } from 'express';
import auth from '../../middleware/auth.js';

import { deleteAllMessagesFromRoom, deleteMessageFromRoom, getConversations, getMessages, sendAudioMessage, sendMessage } from './socket.controller.js';
import { uploadAudio } from '../../utils/multer.js';

const router = Router();

router.post('/send-message', auth, sendMessage);

router.post('/send-audio', auth, uploadAudio.single('audio'), sendAudioMessage);

router.get('/messages', auth, getMessages);

router.get('/conversations', auth, getConversations);

router.delete('/delete-all-messages', auth, deleteAllMessagesFromRoom);

router.delete('/delete-message', auth, deleteMessageFromRoom);

export default router;
