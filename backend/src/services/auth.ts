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
   * Génère un access token
   */
    generateAccessToken(userId: Types.ObjectId) {
        return generateAccessToken(userId);
    },

    /**
   * Génère et sauvegarde un refresh token
   */
    async generateAndSaveRefreshToken(userId: Types.ObjectId) {
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
   * Génère les tokens et sauvegarde le refresh token
   */
    async generateTokens(userId: Types.ObjectId) {
        const accessToken = this.generateAccessToken(userId);
        const refreshToken = await this.generateAndSaveRefreshToken(userId);

        return { accessToken, refreshToken };
    },
};
