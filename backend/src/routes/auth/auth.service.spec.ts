import mongoose from 'mongoose';

import { MongoMemoryServer } from 'mongodb-memory-server';
import logger from '../../utils/logger.js';
import User from '../../models/user.js';
import bcrypt from 'bcrypt';
import { authenticate, generateTokens, validateCredentials } from './auth.service.js';

jest.mock('bcrypt', () => ({
    compare: jest.fn(), // ✅ Mock manuel de compare
}));

let mongoServer: MongoMemoryServer;
describe('auth service tests', () => {
    beforeAll(async () => {
        logger.info = jest.fn(); // pour mute les logs
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());

        User.findOne = jest.fn(); // Mock de la méthode Mongoose
        User.findById = jest.fn(); // Mock de la méthode Mongoose
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
        jest.restoreAllMocks();
    });

    it('should validate credentials', async () => {
        const { valid, error } = validateCredentials('testuser', 'password123');
        expect(valid).toBe(true);
        expect(error).toBeUndefined();
    });

    it ('should not validate with empty credentials', async () => {
        const { valid: emptyValid, error: emptyError } = validateCredentials('', '');
        expect(emptyValid).toBe(false);
        expect(emptyError).toBeDefined();
    });

    it ('should not validate with invalid credentials', async () => {
        const { valid: invalidValid, error: invalidError } = validateCredentials('t', 'p');
        expect(invalidValid).toBe(false);
        expect(invalidError).toBeDefined();

        const { valid: undefinedValid, error: undefinedError } = validateCredentials('testest', 'sh');
        expect(undefinedValid).toBe(false);
        expect(undefinedError).toBeDefined();

        const { valid: undefinedValid2, error: undefinedError2 } = validateCredentials('sh', 'testtest');
        expect(undefinedValid2).toBe(false);
        expect(undefinedError2).toBeDefined();
    });

    test('should authenticate a user', async () => {
        const mockUser = { username: 'testuser', password: 'hashedPassword' };

        (User.findOne as jest.Mock).mockResolvedValue(mockUser); // Simule un utilisateur trouvé
        (bcrypt.compare as jest.Mock).mockResolvedValue(true); // ✅ Mock bcrypt.compare

        const result = await authenticate('testuser', 'password123');

        expect(result).toEqual(mockUser);
        expect(User.findOne).toHaveBeenCalledWith({ username: 'testuser' });
        expect(bcrypt.compare).toHaveBeenCalledWith('password123', 'hashedPassword');
    });

    test('should throw an error if user not found', async () => {
        (User.findOne as jest.Mock).mockResolvedValue(null); // Simule aucun utilisateur trouvé
        (bcrypt.compare as jest.Mock).mockResolvedValue(false); // Simule un mot de passe incorrect
        await expect(authenticate('nonexistentuser', 'password123')).rejects.toThrow('User not found');
    });

    test('should throw an error if password is incorrect', async () => {
        const mockUser = { username: 'testuser', password: 'hashedPassword' };
        (User.findOne as jest.Mock).mockResolvedValue(mockUser); // Simule un utilisateur trouvé
        (bcrypt.compare as jest.Mock).mockResolvedValue(false); // Simule un mot de passe incorrect
        await expect(authenticate('testuser', 'wrongpassword')).rejects.toThrow('Invalid credentials');
    });

    it('should generate a pair of tokens', async () => {
        const userId = new mongoose.Types.ObjectId();
        const mockUser = {
            _id: userId,
            username: 'testuser',
            password: 'hashedPassword',
        };
        (User.findById as jest.Mock).mockResolvedValue(mockUser); // Simule aucun utilisateur trouvé

        const { accessToken, refreshToken } = await generateTokens(userId);

        expect(accessToken).toBeDefined();
        expect(refreshToken).toBeDefined();
    });

    it('should throw an error if user not found for token generation', async () => {
        const userId = new mongoose.Types.ObjectId();
        (User.findById as jest.Mock).mockResolvedValue(null); // Simule aucun utilisateur trouvé
        await expect(generateTokens(userId)).rejects.toThrow('User not found');
    });
});
