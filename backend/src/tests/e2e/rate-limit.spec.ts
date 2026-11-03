import mongoose from 'mongoose';
import request from 'supertest';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app, { setupRoutes } from '../../app.js';
import logger from '../../utils/logger.js';

// En production l'API est derrière nginx : toutes les requêtes arrivent du
// loopback avec l'IP réelle dans X-Forwarded-For. Le rate limiting doit
// compter par client réel, pas globalement.
let mongoServer: MongoMemoryServer;
describe('rate limiting derrière reverse proxy', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        setupRoutes(app);
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoServer.stop();
        jest.restoreAllMocks();
    });

    const failedLogin = (ip: string) => request(app)
        .post('/api/auth/login')
        .set('X-Forwarded-For', ip)
        .send({ username: 'inconnu', password: 'mauvais-mdp' });

    it('bloque un client après 10 tentatives sans bloquer les autres', async () => {
        for (let i = 0; i < 10; i++) {
            const res = await failedLogin('203.0.113.1');
            expect(res.statusCode).not.toEqual(429);
        }
        expect((await failedLogin('203.0.113.1')).statusCode).toEqual(429);

        // Un autre utilisateur derrière le même nginx n'est pas impacté.
        expect((await failedLogin('203.0.113.2')).statusCode).not.toEqual(429);
    });

    it('ne fait confiance à X-Forwarded-For que depuis le loopback', async () => {
        const res = await request(app).get('/api/health').set('X-Forwarded-For', '198.51.100.7');
        expect(res.statusCode).toEqual(200);
        expect(app.get('trust proxy fn')('127.0.0.1', 0)).toBe(true);
        expect(app.get('trust proxy fn')('198.51.100.7', 0)).toBe(false);
    });
});
