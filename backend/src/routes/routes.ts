import { Router, static as static_, Response } from 'express';
import authRoutes from './auth/auth.routes.js';
import ginkoRoutes from './ginko/ginko.routes.js';
import userRoutes from './user/user.routes.js';
import socketRoutes from './socket/socket.routes.js';
import { uploadsPath } from '../config.js';
import ruRoutes from './ru/ru.routes.js';
import sectorRoutes from './sector/sector.routes.js';

// express.static sert le .webm en `video/webm`, ce que l'élément <audio>
// (just_audio web) refuse de charger (MediaError). On force le type audio.
const audioContentTypes: Record<string, string> = {
    '.webm': 'audio/webm',
    '.m4a': 'audio/mp4',
    '.aac': 'audio/aac',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
};

const api = Router()
    .use('/auth', authRoutes)
    .use('/ginko', ginkoRoutes)
    .use('/users', userRoutes)
    .use('/socket', socketRoutes)
    .use('/ru', ruRoutes)
    .use('/sectors', sectorRoutes)
    .use('/uploads', static_(uploadsPath, {
        setHeaders: (res, filePath) => {
            // Helmet pose CORP: same-origin, ce qui empêche les éléments
            // <audio>/<img> d'une autre origine (app web sur un autre port)
            // de charger ces fichiers. On autorise le cross-origin.
            res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
            const ext = filePath.slice(filePath.lastIndexOf('.')).toLowerCase();
            const type = audioContentTypes[ext];
            if (type) res.setHeader('Content-Type', type);
        },
    }))
    .get('/health', (_req, res: Response) => {
        res.status(200).json({ message: 'API is alive !' });
    });

export default Router().use('/api', api);
