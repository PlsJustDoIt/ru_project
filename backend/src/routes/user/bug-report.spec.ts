import request from 'supertest';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import app, { setupRoutes } from '../../app.js';
import BugReport from '../../models/bugReport.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;

describe('POST /api/users/send-bug-report', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('accepte un signalement anonyme (mode invité)', async () => {
        const res = await request(app).post('/api/users/send-bug-report')
            .field('description', 'Le menu ne charge pas')
            .field('platform', 'android');
        expect(res.statusCode).toBe(201);
        const saved = await BugReport.findById(res.body.bugReport._id);
        expect(saved?.description).toBe('Le menu ne charge pas');
        expect(saved?.user).toBeUndefined();
    });

    it('rattache le signalement à l\'utilisateur connecté', async () => {
        const reg = await request(app).post('/api/auth/register')
            .send({ username: 'reporter', password: 'password123' });
        const res = await request(app).post('/api/users/send-bug-report')
            .set('authorization', `Bearer ${reg.body.accessToken}`)
            .field('description', 'Crash au lancement');
        expect(res.statusCode).toBe(201);
        expect(res.body.bugReport.user).toBeDefined();
    });

    it('refuse un token invalide (403) au lieu de passer en anonyme', async () => {
        const res = await request(app).post('/api/users/send-bug-report')
            .set('authorization', 'Bearer pas-un-jwt')
            .field('description', 'x');
        expect(res.statusCode).toBe(403);
    });
});
