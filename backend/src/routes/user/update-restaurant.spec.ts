import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
let accessToken: string;
let restaurantObjectId: string;

describe('PUT /api/users/update-restaurant', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        const resto = await Restaurant.create({
            restaurantId: 'r135', name: 'RU Test', address: 'a', description: 'd',
        });
        restaurantObjectId = resto._id.toString();
        const reg = await request(app).post('/api/auth/register')
            .send({ username: 'updresto', password: 'password123' });
        accessToken = reg.body.accessToken;
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('sans token -> 401', async () => {
        const res = await request(app).put('/api/users/update-restaurant')
            .send({ restaurantId: restaurantObjectId });
        expect(res.statusCode).toBe(401);
    });

    it('id invalide -> 400', async () => {
        const res = await request(app).put('/api/users/update-restaurant')
            .set('authorization', `Bearer ${accessToken}`)
            .send({ restaurantId: 'pas-un-objectid' });
        expect(res.statusCode).toBe(400);
    });

    it('restaurant inexistant -> 404', async () => {
        const fakeId = new mongoose.Types.ObjectId().toString();
        const res = await request(app).put('/api/users/update-restaurant')
            .set('authorization', `Bearer ${accessToken}`)
            .send({ restaurantId: fakeId });
        expect(res.statusCode).toBe(404);
    });

    it('succès -> 200 et /me reflète le nouveau restaurant', async () => {
        const res = await request(app).put('/api/users/update-restaurant')
            .set('authorization', `Bearer ${accessToken}`)
            .send({ restaurantId: restaurantObjectId });
        expect(res.statusCode).toBe(200);
        expect(res.body.restaurantId).toBe(restaurantObjectId);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${accessToken}`);
        expect(me.body.user.restaurantId).toBe(restaurantObjectId);
    });
});
