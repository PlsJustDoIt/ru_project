import { Router, static as static_, Response } from 'express';
import authRoutes from './auth/auth.routes.js';
import ginkoRoutes from './ginko/ginko.routes.js';
import userRoutes from './user/user.routes.js';
import socketRoutes from './socket/socket.routes.js';
import { uploadsPath } from '../config.js';
import ruRoutes from './ru/ru.routes.js';
import sectorRoutes from './sector/sector.routes.js';

const api = Router()
    .use('/auth', authRoutes)
    .use('/ginko', ginkoRoutes)
    .use('/users', userRoutes)
    .use('/socket', socketRoutes)
    .use('/ru', ruRoutes)
    .use('/sectors', sectorRoutes)
    .use('/uploads', static_(uploadsPath))
    .use('/health', (res: Response) => {
        res.status(200).json({ message: 'API is alive !' });
    });

export default Router().use('/api', api);
