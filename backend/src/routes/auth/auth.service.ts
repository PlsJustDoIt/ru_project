import bcrypt from 'bcrypt';
import User from '../../models/user.js';
import RefreshToken from '../../models/refreshToken.js';
import { Types } from 'mongoose';
import jwt from 'jsonwebtoken';
import logger from '../../utils/logger.js';
import { jwtAccessSecret, jwtRefreshSecret } from '../../config.js';

const USERNAME_MIN_LENGTH = 3;
const USERNAME_MAX_LENGTH = 32;
const PASSWORD_MIN_LENGTH = 8;
// bcrypt ne prend en compte que les 72 premiers octets ; au-delà la limite n'a pas de sens.
const PASSWORD_MAX_LENGTH = 72;

const generateRefreshToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, jwtRefreshSecret, { expiresIn: '7d' });
};

const generateAccessToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, jwtAccessSecret, { expiresIn: '1h' });
};

/**
 * Valide les champs username et password à l'inscription / au changement de mot de passe.
 * Applique la politique de mot de passe (longueur). Ne pas utiliser à la connexion :
 * on ne doit pas verrouiller les comptes existants dont le mot de passe est plus court
 * que la politique actuelle (cf. validateLoginFields).
 */
const validateCredentials = (username: string, password: string): { valid: boolean; error?: string } => {
    if (!username || !password) {
        return { valid: false, error: 'Username or password field is missing' };
    }

    username = username.trim();
    password = password.trim();

    if (username.length < USERNAME_MIN_LENGTH || username.length > USERNAME_MAX_LENGTH) {
        return {
            valid: false,
            error: `Invalid length for username (length must be between ${USERNAME_MIN_LENGTH} and ${USERNAME_MAX_LENGTH} characters)`,
        };
    }

    if (password.length < PASSWORD_MIN_LENGTH || password.length > PASSWORD_MAX_LENGTH) {
        return {
            valid: false,
            error: `Invalid length for password (length must be between ${PASSWORD_MIN_LENGTH} and ${PASSWORD_MAX_LENGTH} characters)`,
        };
    }

    return { valid: true };
};

/**
 * Validation légère pour la connexion : on vérifie seulement la présence des champs
 * (et une borne max raisonnable pour éviter un hash coûteux sur une entrée énorme).
 * La validité réelle est décidée par bcrypt.compare.
 */
const validateLoginFields = (username: string, password: string): { valid: boolean; error?: string } => {
    if (!username || !password) {
        return { valid: false, error: 'Username or password field is missing' };
    }
    if (password.length > PASSWORD_MAX_LENGTH) {
        return { valid: false, error: 'Invalid credentials' };
    }
    return { valid: true };
};

/**
 * Authentifie un utilisateur
 */
const authenticate = async (username: string, password: string) => {
    const user = await User.findOne({ username });
    if (!user) throw new Error('User not found');

    const isMatch = await bcrypt.compare(password, user.password);
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

export { validateCredentials, validateLoginFields, authenticate, generateTokens, generateAccessToken, generateAndSaveRefreshToken };
