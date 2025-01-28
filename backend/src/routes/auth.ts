import { Router, Request, Response } from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import User from '../models/user.js';
import RefreshToken from '../models/refreshToken.js';
import { Types } from 'mongoose';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import path from 'path';
import fs from 'fs';
import isProduction from '../config.js';
const router = Router();

const TEXT_MIN_LENGTH = 3;
const TEXT_MAX_LENGTH = 32;

const generateAccessToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_ACCESS_SECRET as jwt.Secret, { expiresIn: '1h' });
};

const generateRefreshToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_REFRESH_SECRET as jwt.Secret, { expiresIn: '7d' });
};

router.post('/register', async (req, res) => {
    try {
        let { username, password } = req.body;
        // username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces
        if (!username || !password) {
            logger.error('Username or password field dosn\'t exists');
            return res.status(400).json({ error: 'Username or password field dosn\'t exists' });
        }

        username = username.trim();
        password = password.trim();

        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: { message: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`, field: 'username' } });
        }

        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: { message: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`, field: 'password' } });
        }

        let user = await User.findOne({ username });
        if (user != null) {
            logger.error('User already exists');
            return res.status(400).json({ error: { message: 'User already exists', field: 'username' } }); // TODO utiliser ceci ailleurs
        }
        user = new User({ username,
            password });
        await user.save();
        // const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET as jwt.Secret, { expiresIn: '1h' });
        // Générer les tokens
        const accessToken = generateAccessToken(user._id);
        const refreshToken = generateRefreshToken(user._id);

        // Sauvegarder le refresh token dans la base (optionnel)
        const refreshTokenInstance = new RefreshToken({ token: refreshToken,
            userId: user._id,
            expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) });
        await refreshTokenInstance.save();
        logger.info(`Engistrement de l'utilisateur ${username}`);
        return res.status(201).json({ accessToken,
            refreshToken });
    } catch (err) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

router.post('/login', async (req, res) => {
    try {
        let { username, password } = req.body;
        // test authentification header
        if (req.headers.authorization && req.headers.authorization.length > 0) {
            logger.error('User is already connected');
            return res.status(400).json({ error: 'User is already connected' });
        }

        // username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces

        if (!username || !password) {
            logger.error('Username or password field dosn\'t exists');
            return res.status(400).json({ error: 'Username or password field dosn\'t exists' });
        }

        username = username.trim();
        password = password.trim();

        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: { message: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`, field: 'username' } });
        }

        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: { message: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`, field: 'password' } });
        }

        const user = await User.findOne({ username });
        if (!user) return res.status(400).json({ error: 'This user does not exists' });
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ error: 'Invalid username or password' });
        // const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET as jwt.Secret, { expiresIn: '1h' });
        // Générer les tokens
        const accessToken = generateAccessToken(user._id);
        const refreshToken = generateRefreshToken(user._id);

        // Sauvegarder le refresh token
        const refreshTokenInstance = new RefreshToken({ token: refreshToken,
            userId: user._id,
            expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) });
        const response = await refreshTokenInstance.save();

        if (!response) {
            logger.error('Error while saving the refresh token');
            return res.status(500).json({ error: 'An error has occured' });
        }

        logger.info(`Connexion de l'utilisateur ${username}`);

        return res.json({ accessToken, refreshToken });
    } catch (err) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

router.post('/token', auth, async (req, res) => {
    const refreshToken = req.body.refreshToken;
    try {
        const existingToken = await RefreshToken.findOne({ token: refreshToken });
        logger.info('existingToken found : ' + existingToken);
        if (!existingToken) {
            logger.error('Invalid refresh token');
            return res.status(403).json({ error: 'Invalid refresh token' });
        }

        // Vérifier si le token est expiré (optionnel, mais si tu stockes l'expiration dans la base)
        if (existingToken.expires.getTime() < Date.now()) {
            await RefreshToken.findOneAndDelete({ refreshToken });
            // peut etre refaire un refresh token au lieu de renvoyer erreur ???
            logger.error('Refresh token expired');
            return res.status(403).json({ error: 'Refresh token expired' });
        }

        // Vérifier si le refresh token est valide
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET as jwt.Secret) as JwtPayload;
        logger.info(decoded);

        const userIdFromToken = decoded.id;

        // 5. Vérifier si l'ID utilisateur du token correspond à l'ID enregistré avec le refresh token
        if (existingToken.userId.toString() !== userIdFromToken) {
            logger.error('Refresh token does not belong to the user');
            return res.status(403).json({ error: 'Refresh token does not belong to the user' });
        }

        // Générer un nouveau access token
        const accessToken = generateAccessToken(userIdFromToken); // Tu peux utiliser la fonction définie plus tôt

        const userUsername = await User.findById(userIdFromToken).select('username');

        logger.info(`Nouveau token créé pour l'utilisateur ${userUsername} :\n accessToken: ${accessToken}`);

        return res.json({ accessToken });

        // });
    } catch (err) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

router.post('/logout', auth, async (req, res) => { // TODO : à voir si on doit utiliser le middleware auth
    const refreshToken = req.body.refreshToken;
    try {
        await RefreshToken.findOneAndDelete({ token: refreshToken });
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'problem with the middleware' });
        }
        logger.info(`Déconnexion de l'utilisateur ${user.username}`);
        return res.json({ message: 'Logged out' });
    } catch (err) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

router.delete('/delete-account', auth, async (req: Request, res: Response) => {
    const refreshToken = req.body.refreshToken;
    if (!refreshToken) {
        logger.error('No refresh token provided');
        return res.status(500).json({ error: 'An error has occured' });
    }
    try {
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }
        let dirname = path.resolve();
        if (isProduction) {
            dirname = path.join(dirname, 'dist');
        }
        if (user.avatarUrl !== 'uploads/avatar/default.png') {
            fs.unlink(path.join(dirname, user.avatarUrl), (err) => {
                if (err) {
                    logger.error('Could not delete avatar : ' + err);
                }
            });
        }
        await user.deleteOne();
        await RefreshToken.findOneAndDelete({ token: refreshToken });
        return res.json({ message: 'User deleted' });
    } catch (err: unknown) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

export default router;
