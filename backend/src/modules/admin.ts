import AdminJS, { CurrentAdmin, DefaultAuthenticatePayload, DefaultAuthProvider } from 'adminjs';
import * as AdminJSMongoose from '@adminjs/mongoose';
import { ComponentLoader } from 'adminjs';
import AdminJSExpress from '@adminjs/express';
import { join } from 'path';
import { componentsPath, isProduction, rootDir } from '../config.js';
import BugReport from '../models/bugReport.js';
import User from '../models/user.js';
import { authenticate } from '../routes/auth/auth.service.js';
import Sector from '../models/sector.js';

import express from 'express';
import logger from '../utils/logger.js';
import { Express } from 'express';
import Restaurant from '../models/restaurant.js';

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
                sort: {
                    sortBy: 'createdAt',
                    direction: 'desc',
                },
                properties: {
                    user: {
                        reference: 'User', // Référence au modèle User
                    },
                    _id: {
                        isVisible: { list: false, show: true, edit: false },
                    },
                    screenshot_url: {
                        components: {
                            list: componentLoader.add('ScreenshotUrlList', join(componentsPath, 'screenshot-url-list')),
                            show: componentLoader.add('ScreenshotUrlShow', join(componentsPath, 'screenshot-url-show')),
                            edit: componentLoader.add('ScreenshotUrlEdit', join(componentsPath, 'screenshot-url-edit')),
                        },
                    },
                },
            },
        },
        {
            resource: User,
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
                            list: componentLoader.add('AvatarUrlList', join(componentsPath, 'avatar-url-list')),
                            show: componentLoader.add('AvatarUrlShow', join(componentsPath, 'avatar-url-show')),
                            edit: componentLoader.add('AvatarUrlEdit', join(componentsPath, 'avatar-url-edit')),
                        },
                    },
                },
            },
        },
        {
            resource: Restaurant,
            options: {
                properties: {
                    _id: {
                        isVisible: { list: false, show: true, edit: false },
                    },
                },
            },

        },
        {
            resource: Sector,
            options: {
                sort: {
                    sortBy: 'sectorId',
                    direction: 'asc',
                },
                properties: {
                    _id: {
                        isVisible: { list: false, show: true, edit: false },
                    },
                },
            },
        },
    ],
    rootPath: '/admin',
    componentLoader,
});

const customRouter = express.Router();

const authenticateAdmin = (payload: DefaultAuthenticatePayload): Promise<CurrentAdmin | null> => {
    return new Promise((resolve) => {
        authenticate(payload.email, payload.password)
            .then((user) => {
                if (user.role === 'admin') {
                    resolve({ email: user.username });
                } else {
                    resolve(null);
                }
            })
            .catch((error) => {
                logger.error('Authentication error: %o', error);
                resolve(null);
            });
    });
};

const authProvider = new DefaultAuthProvider({
    componentLoader,
    authenticate: authenticateAdmin,
});

// const sessionStore = process.env.NODE_ENV === 'production'
//   ? MongoStore.create({
//       mongoUrl: process.env.MONGO_URI,
//       ttl: 14 * 24 * 60 * 60,
//     })
//   : undefined; // MemoryStore sera utilisé par défaut

const adminRouter = AdminJSExpress.buildAuthenticatedRouter(admin, {
    cookiePassword: process.env.JWT_ACCESS_SECRET ?? 'truc',
    provider: authProvider,

}, null, {
    resave: false,
    saveUninitialized: true,
    secret: process.env.JWT_ACCESS_SECRET ?? 'truc',
});

customRouter.use(admin.options.rootPath, adminRouter);

logger.info(`admin JS running on http://localhost:${5000}${admin.options.rootPath}`);

const adminJsSetup = (app: Express) => {
    app.use(admin.options.rootPath, adminRouter);
    if (isProduction) {
        app.use('/admin', express.static(join(rootDir, '.adminjs')));
    } else {
        admin.watch();
    }
};

export default adminJsSetup;
