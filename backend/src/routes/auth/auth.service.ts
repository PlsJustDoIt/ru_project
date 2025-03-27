import { compare } from 'bcrypt';
import User from '../../models/user.js';
import RefreshToken from '../../models/refreshToken.js';
import { Types } from 'mongoose';
import jwt from 'jsonwebtoken';
import logger from '../../utils/logger.js';

const TEXT_MIN_LENGTH = 3;
const TEXT_MAX_LENGTH = 32;

const generateRefreshToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_REFRESH_SECRET as jwt.Secret, { expiresIn: '7d' });
};

const generateAccessToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_ACCESS_SECRET as jwt.Secret, { expiresIn: '1h' });
};

/**
 * Valide les champs username et password
 */
const validateCredentials = (username: string, password: string): { valid: boolean; error?: string } => {
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
};

// const validateUsername = (username:string) {
//     if (username)
// }

/**
 * Authentifie un utilisateur
 */
const authenticate = async (username: string, password: string) => {
    const user = await User.findOne({ username });
    if (!user) throw new Error('User not found');

    const isMatch = await compare(password, user.password);
    if (!isMatch) throw new Error('Invalid credentials');

    logger.info(`User ${username} authenticated successfully`);

    return user;
};

/**
 * Génère et sauvegarde un refresh token
 */
const generateAndSaveRefreshToken = async (userId: Types.ObjectId) => {
    const refreshToken = generateRefreshToken(userId);

    const refreshTokenInstance = new RefreshToken({
        token: refreshToken,
        userId,
        expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    await refreshTokenInstance.save();

    return refreshToken;
};

/**
     * Generates a new access token and refresh token for the given user ID.
     * The refresh token is saved to the database.
     *
     * @param userId The ID of the user to generate tokens for.
     * @returns An object containing the access token and refresh token.
     */
const generateTokens = async (userId: Types.ObjectId) => {
    const user = await User.findById(userId);
    if (!user) {
        throw new Error('User not found');
    }
    const accessToken = generateAccessToken(userId);
    const refreshToken = await generateAndSaveRefreshToken(userId);

    return { accessToken, refreshToken };
};

export { validateCredentials, authenticate, generateTokens, generateAccessToken, generateAndSaveRefreshToken };
