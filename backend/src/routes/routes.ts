import express from 'express';
import authRoutes from './auth.js';
import userRoutes from './users.js';
import ruRoutes from './ru.js';
import ginkoRoutes from './ginko.js';
import socketRoute from './socket.js';
import { Response } from 'express';

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/ru', ruRoutes);
router.use('/ginko', ginkoRoutes);
router.use('/socket', socketRoute);
router.get('/health', (req, res: Response) => {
    res.status(200).json({ message: 'API is alive !' });
});

export default router;
