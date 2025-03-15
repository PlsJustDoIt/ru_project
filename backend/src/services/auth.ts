import { compare } from 'bcrypt';
import User from '../models/user.js';
import RefreshToken from '../models/refreshToken.js';
import { Types } from 'mongoose';
import jwt from 'jsonwebtoken';
import logger from './logger.js';

const generateRefreshToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_REFRESH_SECRET as jwt.Secret, { expiresIn: '7d' });
};

const generateAccessToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_ACCESS_SECRET as jwt.Secret, { expiresIn: '1h' });
};

export const AuthService = {

    /**
   * Valide les champs username et password
   */
    validateCredentials(username: string, password: string): { valid: boolean; error?: string } {
        const TEXT_MIN_LENGTH = 3;
        const TEXT_MAX_LENGTH = 32;

        if (!username || !password) {
            return { valid: false, error: 'Username or password field is missing' };
        }

        username = username.trim();
        password = password.trim();

        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
            return {
                valid: false,
                error: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`,
            };
        }

        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH) {
            return {
                valid: false,
                error: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`,
            };
        }

        return { valid: true };
    },

    /**
   * Authentifie un utilisateur
   */
    async authenticate(username: string, password: string) {
        const user = await User.findOne({ username });
        if (!user) throw new Error('User not found');

        const isMatch = await compare(password, user.password);
        if (!isMatch) throw new Error('Invalid credentials');

        logger.info(`User ${username} authenticated successfully`);

        return user;
    },

    /**
     * Generates an access token for the given user ID.
     *
     * @param userId The ID of the user to generate the token for.
     * @returns A string representing the access token.
     */
    async generateAccessToken(userId: Types.ObjectId) {
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }
        return generateAccessToken(userId);
    },

    /**
        * Generates a new refresh token for the given user ID, saves it to the database, and returns the token.
        *
        * @param userId The ID of the user for whom to generate the refresh token.
        * @returns A promise that resolves with the generated refresh token.
        */
    async generateAndSaveRefreshToken(userId: Types.ObjectId) {
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }
        const refreshToken = generateRefreshToken(userId);

        const refreshTokenInstance = new RefreshToken({
            token: refreshToken,
            userId,
            expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        });

        await refreshTokenInstance.save();

        return refreshToken;
    },

    /**
     * Generates a new access token and refresh token for the given user ID.
     * The refresh token is saved to the database.
     *
     * @param userId The ID of the user to generate tokens for.
     * @returns An object containing the access token and refresh token.
     */
    async generateTokens(userId: Types.ObjectId) {
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }
        const accessToken = await this.generateAccessToken(userId);
        const refreshToken = await this.generateAndSaveRefreshToken(userId);

        return { accessToken, refreshToken };
    },
};
