import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
let restaurantObjectId: string;

describe('RU public endpoints', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        const resto = await Restaurant.create({
            restaurantId: 'r135',
            name: 'RU Test',
            address: '1 rue du test',
            description: 'desc',
        });
        restaurantObjectId = resto._id.toString();
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('GET /api/ru/restaurants sans token -> 200 et expose _id comme restaurantId', async () => {
        const res = await request(app).get('/api/ru/restaurants');
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body.restaurants)).toBe(true);
        expect(res.body.restaurants[0].restaurantId).toBe(restaurantObjectId);
        expect(res.body.restaurants[0].name).toBe('RU Test');
    });

    it('GET /api/ru/:id/sectors sans token -> route publique (pas 401/403)', async () => {
        // La route atteint le contrôleur sans token : preuve que `auth` est retiré.
        // (Un resto sans secteur renvoie 500 — comportement pré-existant, hors périmètre.)
        const res = await request(app).get(`/api/ru/${restaurantObjectId}/sectors`);
        expect(res.statusCode).not.toBe(401);
        expect(res.statusCode).not.toBe(403);
    });

    it('GET /api/ru/:id/sectors-sessions sans token -> 401 (reste protégé)', async () => {
        const res = await request(app).get(`/api/ru/${restaurantObjectId}/sectors-sessions`);
        expect(res.statusCode).toBe(401);
    });
});
