import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { connect } from 'mongoose';
import { createWriteStream } from 'fs';
import { join } from 'path';
import logger from './utils/logger.js';
import { isProduction, mongoUri, rootDir } from './config.js';
import { handleImageRequest } from './middleware/imageHandler.js';
import adminJsSetup from './modules/admin.js';

const app = express();

app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());

// Limiteur anti-brute-force dédié au login admin (même politique que
// l'ancien /admin/login sur le process API).
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (req, res) => {
        logger.error(`Too many admin login attempts from ${req.ip}`);
        return res.status(429).json({ error: 'Too many attempts, please try again later.' });
    },
});
app.use('/login', authLimiter);

// Routes de redirection vers les fichiers uploadés, référencées par les
// composants AdminJS (avatar, screenshot de bug report).
app.use('/resources/:model/records/:recordId/uploads/*path', handleImageRequest);
app.use('/resources/uploads/*path', handleImageRequest);

if (isProduction) {
    const accessLogStream = createWriteStream(join(rootDir, 'logs', 'admin-access.log'), { flags: 'a+' });
    app.use(morgan('combined', { stream: accessLogStream }));
} else {
    app.use(morgan('dev'));
}

connect(mongoUri)
    .then(() => logger.info('MongoDB Connected (admin)'))
    .catch(err => logger.error('MongoDB connection error (admin):', err));

adminJsSetup(app);

const ADMIN_PORT = process.env.ADMIN_PORT || 5001;
app.listen(ADMIN_PORT, () => {
    logger.info(`Admin server running on port ${ADMIN_PORT}`);
});

export default app;
