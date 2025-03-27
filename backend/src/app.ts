import express from 'express';
import cors from 'cors';
import compression from 'compression';
import helmet from 'helmet';
import { join } from 'path';
import { rootDir } from './config.js';
import logger from './utils/logger.js';
import rateLimit from 'express-rate-limit';
import routes from './routes/routes.js';

import { handleImageRequest } from './middleware/imageHandler.js'; // Import image request handler
import ruRoutes from './routes/ru.js';

import api from './routes/routes.js';

const app = express();

// Middleware setup
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use(cors());
app.use(compression());

// Rate limiting
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    limit: 50, // Limit each IP to 50 requests per windows
    standardHeaders: 'draft-7', // draft-6: `RateLimit-*` headers; draft-7: combined `RateLimit` header
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers.
    handler: (req, res) => {
        logger.error('Too many requests, please try again later.');
        return res.status(429).json({ error: 'Too many requests, please try again later.' });
    },
});

app.use(limiter);

app.use('/api/ru', ruRoutes);

app.use(api);

// Routes
app.use('/api', routes);

// Image handling routes
app.use('/admin/resources/:model/records/:recordId/uploads/*', handleImageRequest);
app.use('/admin/api/resources/:model/records/:recordId/uploads/*', handleImageRequest);
app.use('/resources/:model/records/:recordId/uploads/*', handleImageRequest);
app.use('/api/resources/:model/records/:recordId/uploads/*', handleImageRequest);
app.use('/admin/resources/uploads/*', handleImageRequest);
app.use('/admin/api/resources/uploads/*', handleImageRequest);
app.use('/resources/uploads/*', handleImageRequest);
app.use('/api/resources/uploads/*', handleImageRequest);

app.get('/test-socket', (req, res) => {
    return res.sendFile(join(rootDir, 'public', 'socket-test.html'));
});

export default app;
