import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
let restaurantObjectId: string;

describe('register avec restaurantId', () => {
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
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('register avec restaurantId valide (ObjectId) -> /me renvoie l\'id CROUS', async () => {
        const reg = await request(app).post('/api/auth/register').send({
            username: 'withresto', password: 'password123', restaurantId: restaurantObjectId,
        });
        expect(reg.statusCode).toBe(201);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${reg.body.accessToken}`);
        expect(me.statusCode).toBe(200);
        // L'id officiel CROUS est l'identifiant exposé au client
        expect(me.body.user.restaurantId).toBe('r135');
    });

    it('register avec l\'id CROUS directement ("r135") -> accepté aussi', async () => {
        const reg = await request(app).post('/api/auth/register').send({
            username: 'crousid', password: 'password123', restaurantId: 'r135',
        });
        expect(reg.statusCode).toBe(201);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${reg.body.accessToken}`);
        expect(me.body.user.restaurantId).toBe('r135');
    });

    it('register sans restaurantId -> compte créé, pas de restaurant', async () => {
        const reg = await request(app).post('/api/auth/register').send({
            username: 'noresto', password: 'password123',
        });
        expect(reg.statusCode).toBe(201);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${reg.body.accessToken}`);
        expect(me.body.user.restaurantId).toBeUndefined();
    });

    it('register avec restaurantId inexistant -> 400', async () => {
        const fakeId = new mongoose.Types.ObjectId().toString();
        const reg = await request(app).post('/api/auth/register').send({
            username: 'badresto', password: 'password123', restaurantId: fakeId,
        });
        expect(reg.statusCode).toBe(400);
    });
});
