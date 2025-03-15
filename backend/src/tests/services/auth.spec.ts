import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import logger from '../../services/logger.js';
import { AuthService } from '../../services/auth.js';
import RefreshToken from '../../models/refreshToken.js';
import User from '../../models/user.js';

let mongoServer: MongoMemoryServer;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let user: any;

describe('auth service', () => {
    beforeAll(async () => {
        logger.info = jest.fn(); // pour mute les logs
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
    });

    beforeEach(async () => {
        user = new User({
            username: 'testuser',
            password: 'password123',
        });
        await user.save();
    });

    afterEach(async () => {
        await User.deleteMany({});
        await RefreshToken.deleteMany({});
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
        jest.restoreAllMocks();
    });

    it('should generate a new access token', async () => {
        const token = await AuthService.generateAccessToken(user._id);
        expect(token).toBeDefined();
        expect(typeof token).toBe('string');
    });

    it('should throw an error because of unknown userId', async () => {
        await expect(AuthService.generateAccessToken(new mongoose.Types.ObjectId())).rejects.toThrow('User not found');
        await expect(AuthService.generateAndSaveRefreshToken(new mongoose.Types.ObjectId())).rejects.toThrow('User not found');
        await expect(AuthService.generateTokens(new mongoose.Types.ObjectId())).rejects.toThrow(Error);
    });

    it('should generate a new refresh token', async () => {
        const token = await AuthService.generateAndSaveRefreshToken(user._id);
        expect(token).toBeDefined();
        expect(typeof token).toBe('string');
        expect(await RefreshToken.findOne({ userId: user._id })).toBeDefined();
    });

    it('should generate an access token and a refresh token', async () => {
        const userId = user._id;
        const { accessToken, refreshToken } = await AuthService.generateTokens(userId);
        expect(accessToken).toBeDefined();
        expect(typeof accessToken).toBe('string');
        expect(refreshToken).toBeDefined();
        expect(typeof refreshToken).toBe('string');
        expect(await RefreshToken.findOne({ userId })).toBeDefined();
    });

    it('should authenticate a user', async () => {
        const authenticatedUser = await AuthService.authenticate('testuser', 'password123');
        expect(authenticatedUser).toBeDefined();
        expect(authenticatedUser.username).toBe('testuser');
    });

    it('should throw an error because of invalid credentials', async () => {
        await expect(AuthService.authenticate('testuser', 'wrongpassword')).rejects.toThrow('Invalid credentials');
    });

    it('should throw an error if the user does not exist', async () => {
        await expect(AuthService.authenticate('not_existing', 'password123')).rejects.toThrow('User not found');
    });
});
