import isProduction from './config.js';
import express, { Response } from 'express';
import mongoose from 'mongoose';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import ruRoutes from './routes/ru.js';
import ginkoRoutes from './routes/ginko.js';
import cors from 'cors';
import fs from 'fs';
// import https from 'https';
import path from 'path';
import morgan from 'morgan';
import logger from './services/logger.js';
import { exit } from 'process';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import compression from 'compression';
import helmet from 'helmet';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yaml';
import { socketService } from './services/socket.js';
import socketRoute from './routes/socket.js';

if (!isProduction) {
    dotenv.config();
}

const app = express();
logger.info('MONGO_URI: ' + process.env.MONGO_URI);

mongoose.set('strictQuery', false);

// Rate limiting
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    limit: 30, // Limit each IP to 15 requests per windowMs
    standardHeaders: 'draft-7', // draft-6: `RateLimit-*` headers; draft-7: combined `RateLimit` header
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers.
    // store: ... , // Redis, Memcached, etc. See below.
    handler: (req, res) => {
        logger.error('Too many requests, please try again later.');
        return res.status(429).json({ error: 'Too many requests, please try again later.' });
    },
});

app.use(helmet({ contentSecurityPolicy: false }));
app.use(limiter);
app.use(express.json());
app.use(cors());
app.use(compression());

if (isProduction) {
    console.log('lancement en production');
    // define dirnames
    const __dirname = path.dirname(path.resolve());
    // set up log file stream in logs folder
    const accessLogStream = fs.createWriteStream(path.join(__dirname, 'logs', 'access.log'), { flags: 'a+' });
    // log requests combined format
    app.use(morgan('combined', { stream: accessLogStream }));
    app.use('/api/uploads', express.static('../uploads'));
} else {
    console.log('lancement en dev');
    app.use(morgan('dev'));
    app.use('/api/uploads', express.static('uploads'));
}

if (process.env.MONGO_URI == null) {
    logger.error('MONGO_URI is not defined');
    exit(1);
}

mongoose.connect(process.env.MONGO_URI)
    .then(() => logger.info('MongoDB Connected'))
    .catch(err => logger.error('MongoDB connection error:', err));

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/ru', ruRoutes);
app.use('/api/ginko', ginkoRoutes);
app.use('/api/socket', socketRoute);
app.get('/api/health', (res: Response) => {
    res.status(200).json({ message: 'API is alive !' });
});

// app.use((error: any, req: Request, res: Response, next: NextFunction) => {
//     res.status(500).json({ message: error.message, stack: error.stack, path: req.path });
// });

// Swagger
const swaggerFilePath = path.join(path.resolve(), 'swagger.yaml');
const file = fs.readFileSync(swaggerFilePath, 'utf8');
const swaggerDocument = YAML.parse(file);
swaggerUi.setup(swaggerDocument);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));
app.get('/test-socket', (req, res) => {
    return res.sendFile(path.join(path.resolve(), 'public', 'socket-test.html'));
});

const PORT = process.env.PORT || 5000;

// if (!isProduction) {
//   app.listen(PORT, () => logger.info(`Server http running on port ${PORT}`));
// } else {
//   const options = {
//     key: fs.readFileSync('/etc/ssl/private/server.key'),
//     cert: fs.readFileSync('/etc/ssl/certs/server.crt')
//   };
//   const server = https.createServer(options,app);
//   server.listen(PORT, () => logger.info(`Server https running on port ${PORT}`));
// }

const server = app.listen(PORT, () => logger.info(`Server http running on port ${PORT}`));
// Attach Socket.IO to the existing server
socketService.initialize(server);
