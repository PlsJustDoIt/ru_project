import { isProduction, uploadsPath, rootDir, componentsPath } from './config.js';
import express, { Request, Response } from 'express';
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

const app = express();

mongoose.set('strictQuery', false);

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

app.use(helmet({ contentSecurityPolicy: false }));
app.use(limiter);
app.use(express.json());
app.use(cors());
app.use(compression()); // Compression des réponses
if (isProduction) {
    console.log('lancement en production');
    const accessLogStream = fs.createWriteStream(path.join(rootDir, 'logs', 'access.log'), { flags: 'a+' });
    // log requests combined format
    app.use(morgan('combined', { stream: accessLogStream }));
} else {
    console.log('lancement en dev');
    app.use(morgan('dev'));
}

if (process.env.MONGO_URI == null) {
    logger.error('MONGO_URI is not defined');
    exit(1);
}

logger.info('MONGO_URI: ' + process.env.MONGO_URI);
mongoose.connect(process.env.MONGO_URI)
    .then(() => logger.info('MongoDB Connected'))
    .catch(err => logger.error('MongoDB connection error:', err));

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/ru', ruRoutes);
app.use('/api/ginko', ginkoRoutes);
app.use('/api/socket', socketRoute);
app.use('/api/uploads', express.static(uploadsPath));

// Configurer AdminJS

AdminJS.registerAdapter({
    Resource: AdminJSMongoose.Resource,
    Database: AdminJSMongoose.Database,
});

const componentLoader = new ComponentLoader();
logger.info('componentsPath: ' + componentsPath);
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
                            list: componentLoader.add('ScreenshotUrlList', path.join(componentsPath, 'screenshot-url-list')),
                            show: componentLoader.add('ScreenshotUrlShow', path.join(componentsPath, 'screenshot-url-show')),
                            edit: componentLoader.add('ScreenshotUrlEdit', path.join(componentsPath, 'screenshot-url-edit')),
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
                        isVisible: { list: false, show: false, edit: false }, // temporary
                    },
                    avatarUrl: {
                        components: {
                            list: componentLoader.add('AvatarUrlList', path.join(componentsPath, 'avatar-url-list')),
                            show: componentLoader.add('AvatarUrlShow', path.join(componentsPath, 'avatar-url-show')),
                            edit: componentLoader.add('AvatarUrlEdit', path.join(componentsPath, 'avatar-url-edit')),
                        },
                    },
                },
            },
        },
    ],
    rootPath: '/admin',
    componentLoader,
});

// admin.watch();

const customRouter = express.Router();
const handleImageRequest = (req: Request, res: Response) => {
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

if (isProduction) {
    app.use('/admin', express.static(path.join(rootDir, '.adminjs')));
} else {
    admin.watch();
}

// Swagger
const swaggerFilePath = path.join(rootDir, 'swagger.yaml');
const file = fs.readFileSync(swaggerFilePath, 'utf8');
const swaggerDocument = YAML.parse(file);
swaggerUi.setup(swaggerDocument);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));
app.get('/test-socket', (req, res) => {
    return res.sendFile(path.join(rootDir, 'public', 'socket-test.html'));
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
