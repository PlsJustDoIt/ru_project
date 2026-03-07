import mongoose from 'mongoose';
import request from 'supertest';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app, { setupRoutes } from '../../app.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
describe('auth routes', () => {
    beforeAll(async () => {
        logger.info = jest.fn(); // pour mute les logs
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        setupRoutes(app);
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
        jest.restoreAllMocks();
    });

    it('should create a new user', async () => {
        const res = await request(app)
            .post('/api/auth/register')
            .send({
                username: 'testuser',
                password: 'password123',
            });
        expect(res.statusCode).toEqual(201);
    });

    // describe('RefreshToken Model Test', () => {
    //     beforeAll(async () => {
    //         await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/test');
    //     });

    //     afterAll(async () => {
    //         await mongoose.connection.close();
    //     });

    //     afterEach(async () => {
    //         await RefreshToken.deleteMany({});
    //     });

    //     test('should create & save refresh token successfully', async () => {
    //         const validRefreshToken = new RefreshToken({
    //             token: 'valid-refresh-token',
    //             userId: new mongoose.Types.ObjectId(),
    //             expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    //         });

    //         const savedRefreshToken = await validRefreshToken.save();

    //         expect(savedRefreshToken._id).toBeDefined();
    //         expect(savedRefreshToken.token).toBe(validRefreshToken.token);
    //         expect(savedRefreshToken.userId).toEqual(validRefreshToken.userId);
    //         expect(savedRefreshToken.expires).toEqual(validRefreshToken.expires);
    //     });

    //     test('should fail to save refresh token without required fields', async () => {
    //         const refreshTokenWithoutRequiredField = new RefreshToken({
    //             token: 'test-token',
    //         });

    //         let err;
    //         try {
    //             await refreshTokenWithoutRequiredField.save();
    //         } catch (error) {
    //             err = error;
    //         }
    //         expect(err).toBeInstanceOf(mongoose.Error.ValidationError);
    //     });

    //     test('should find refresh token by token value', async () => {
    //         const refreshToken = new RefreshToken({
    //             token: 'findable-token',
    //             userId: new mongoose.Types.ObjectId(),
    //             expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    //         });

    //         await refreshToken.save();

//         const foundToken = await RefreshToken.findOne({ token: 'findable-token' });
//         expect(foundToken).toBeTruthy();
//         expect(foundToken?.token).toBe('findable-token');
//     });
});
