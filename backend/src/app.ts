import isProduction from './config.js';
import express from 'express';
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
import AdminJS from 'adminjs';
import BugReport from './models/bugReport.js';
import AdminJSExpress from '@adminjs/express';
import * as AdminJSMongoose from '@adminjs/mongoose';
import User from './models/user.js';
import { ComponentLoader } from 'adminjs';

if (!isProduction) {
    dotenv.config();
}

const app = express();
logger.info('MONGO_URI: ' + process.env.MONGO_URI);

mongoose.set('strictQuery', false);

// Rate limiting
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    limit: 50, // Limit each IP to 15 requests per windows
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

if (!isProduction) {
    // Configurer AdminJS

    AdminJS.registerAdapter({
        Resource: AdminJSMongoose.Resource,
        Database: AdminJSMongoose.Database,
    });

    const componentLoader = new ComponentLoader();
    const admin = new AdminJS({
        resources: [
            {
                resource: BugReport,
                options: {
                    properties: {
                        user: {
                            reference: 'User', // Référence au modèle User
                        },
                        _id: {
                            isVisible: { list: false, show: true, edit: false },
                        },
                        screenshot_url: {
                            components: {
                                list: isProduction ? componentLoader.add('ScreenshotUrlList', '../components/screenshot-url-list') : componentLoader.add('ScreenshotUrlList', './components/screenshot-url-list'),
                                show: isProduction ? componentLoader.add('ScreenshotUrlShow', '../components/screenshot-url-show') : componentLoader.add('ScreenshotUrlShow', './components/screenshot-url-show'),
                                edit: isProduction ? componentLoader.add('ScreenshotUrlEdit', '../components/screenshot-url-edit') : componentLoader.add('ScreenshotUrlEdit', './components/screenshot-url-edit'),
                            },
                        },
                    },
                },
            },
            {
                resource: User,
                // features: [passwordsFeature({ // problèmes si on veut utiliser sa propre méthode de hash
                //     properties: {
                //         encryptedPassword: 'encryptedPassword',
                //     },
                //     hash: async (password: string): Promise<string> => {
                //         const salt = await genSalt(10);
                //         return await hash(password, salt);
                //     },
                //     componentLoader,

                // })],
                options: {
                    properties: {
                        friends: {
                            reference: 'User',
                        },
                        _id: {
                            isVisible: { list: false, show: true, edit: false },
                        },
                        password: {
                            isVisible: { list: false, show: false, edit: false },
                        },
                        avatarUrl: {
                            components: {
                                list: isProduction ? componentLoader.add('AvatarUrlList', '../components/avatar-url-list') : componentLoader.add('AvatarUrlList', './components/avatar-url-list'),
                                show: isProduction ? componentLoader.add('AvatarUrlShow', '../components/avatar-url-show') : componentLoader.add('AvatarUrlShow', './components/avatar-url-show'),
                                edit: isProduction ? componentLoader.add('AvatarUrlEdit', '../components/avatar-url-edit') : componentLoader.add('AvatarUrlEdit', './components/avatar-url-edit'),
                            },
                        },
                    },
                },
            },
        ],
        rootPath: '/admin',
        componentLoader,
    });

    admin.watch();

    const customRouter = express.Router();
    const handleImageRequest = (req, res) => {
        const filePath = req.params[0];
        const finalPath = filePath.startsWith('uploads/') ? filePath : `api/uploads/${filePath}`;
        res.redirect(`/${finalPath}`);
    };

    // Gérer les deux patterns d'URL possibles
    customRouter.get('/admin/resources/:model/records/:recordId/uploads/*', handleImageRequest);
    customRouter.get('/admin/api/resources/:model/records/:recordId/uploads/*', handleImageRequest);
    customRouter.get('/resources/:model/records/:recordId/uploads/*', handleImageRequest);
    customRouter.get('/api/resources/:model/records/:recordId/uploads/*', handleImageRequest);

    // Routes pour les accès directs aux uploads
    customRouter.get('/admin/resources/uploads/*', handleImageRequest);
    customRouter.get('/admin/api/resources/uploads/*', handleImageRequest);
    customRouter.get('/resources/uploads/*', handleImageRequest);
    customRouter.get('/api/resources/uploads/*', handleImageRequest);
    const adminRouter = AdminJSExpress.buildRouter(admin, customRouter);
    app.use(admin.options.rootPath, adminRouter);
    logger.info(`admin JS running on http://localhost:${5000}${admin.options.rootPath}`);
}

// app.use('/admin/resources/uploads', express.static(path.resolve() + '/uploads'));

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
