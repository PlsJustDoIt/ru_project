import express, { Express } from 'express';
import cors from 'cors';
import compression from 'compression';
import helmet from 'helmet';
import { join } from 'path';
import { isProduction, rootDir } from './config.js';
import logger from './utils/logger.js';
import rateLimit from 'express-rate-limit';
import routes from './routes/routes.js';

import { handleImageRequest } from './middleware/imageHandler.js';

const app = express();

// CORS : en production, restreindre aux origines explicitement autorisées
// (CORS_ORIGINS, séparées par des virgules). L'app mobile n'envoie pas d'en-tête
// Origin et n'est donc pas impactée ; CORS ne concerne ici que le navigateur.
const corsOrigins = process.env.CORS_ORIGINS?.split(',').map(o => o.trim()).filter(Boolean);
const corsOptions = isProduction && corsOrigins && corsOrigins.length > 0
    ? { origin: corsOrigins }
    : {}; // dev : réflexion de l'origine (comportement par défaut de cors())

// Middleware setup
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use(cors(corsOptions));
app.use(compression());

// Rate limiting global
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    limit: 50, // Limit each IP to 50 requests per windows
    standardHeaders: 'draft-7', // draft-6: `RateLimit-*` headers; draft-7: combined `RateLimit` header
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers.
    handler: (req, res) => {
        logger.error('Too many requests, please try again later.');
        return res.status(429).json({ error: 'Too many requests, please try again later.' });
    },
    skip: (req) => {
        // Le dashboard AdminJS charge beaucoup d'assets : on l'exclut du limiteur
        // global, mais la route de login admin garde un limiteur dédié (cf. authLimiter).
        return req.path.startsWith('/admin');
    },
});

// Limiteur strict anti-brute-force pour les routes sensibles d'authentification.
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    limit: 10, // 10 tentatives par IP par fenêtre
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (req, res) => {
        logger.error(`Too many auth attempts from ${req.ip}`);
        return res.status(429).json({ error: 'Too many attempts, please try again later.' });
    },
});

app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/admin/login', authLimiter);

app.use(limiter);

// Image handling routes
app.use('/admin/resources/:model/records/:recordId/uploads/*path', handleImageRequest);
app.use('/admin/api/resources/:model/records/:recordId/uploads/*path', handleImageRequest);
app.use('/resources/:model/records/:recordId/uploads/*path', handleImageRequest);
app.use('/api/resources/:model/records/:recordId/uploads/*path', handleImageRequest);
app.use('/admin/resources/uploads/*path', handleImageRequest);
app.use('/admin/api/resources/uploads/*path', handleImageRequest);
app.use('/resources/uploads/*path', handleImageRequest);
app.use('/api/resources/uploads/*path', handleImageRequest);

app.get('/test-socket', (req, res) => {
    return res.sendFile(join(rootDir, 'public', 'socket-test.html'));
});

const setupRoutes = (app: Express) => {
    app.use(routes);
};

export default app;
export { setupRoutes };
