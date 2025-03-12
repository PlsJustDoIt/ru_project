import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import User, { IUser } from '../models/user.js';
import RefreshToken from '../models/refreshToken.js';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import { join } from 'path';
import { unlink } from 'fs';
import { avatarPath } from '../config.js';
import { AuthService } from '../services/auth.js';

const router = Router();

router.post('/register', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Validate username and password
        const validation = AuthService.validateCredentials(username, password);
        if (!validation.valid) {
            return res.status(400).json({ error: validation.error });
        }

        // Check if user already exists
        const existingUser = await User.findOne({ username });
        if (existingUser) {
            logger.error('User already exists');
            return res.status(400).json({ error: { message: 'User already exists', field: 'username' } });
        }

        // Create new user
        const user = new User({ username, password });
        await user.save();

        // Generate tokens
        const tokens = await AuthService.generateTokens(user._id);

        logger.info(`User ${username} registered successfully`);
        return res.status(201).json(tokens);
    } catch (err) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occurred' });
    }
});

router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        // Vérifier si l'utilisateur est déjà connecté
        if (req.headers.authorization) {
            return res.status(400).json({ error: 'User is already connected' });
        }

        // Valider les identifiants
        const validation = AuthService.validateCredentials(username, password);
        if (!validation.valid) {
            return res.status(400).json({ error: validation.error });
        }

        // Authentifier l'utilisateur
        const user = await AuthService.authenticate(username, password);

        // Générer les tokens
        const tokens = await AuthService.generateTokens(user._id);

        return res.json(tokens);
    } catch (err) {
        logger.error(err);
        return res.status(500).json({ error: 'An error has occurred' });
    }
});

router.post('/token', auth, async (req, res) => {
    const refreshToken = req.body.refreshToken;
    try {
        const existingToken = await RefreshToken.findOne({ token: refreshToken });
        logger.info('existingToken found : ' + existingToken?.token);
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
        const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET as jwt.Secret) as jwt.JwtPayload;
        logger.info(decoded);

        const userIdFromToken = decoded.id;

        // 5. Vérifier si l'ID utilisateur du token correspond à l'ID enregistré avec le refresh token
        if (existingToken.userId.toString() !== userIdFromToken) {
            logger.error('Refresh token does not belong to the user');
            return res.status(403).json({ error: 'Refresh token does not belong to the user' });
        }

        // Générer un nouveau access token
        const accessToken = AuthService.generateAccessToken(userIdFromToken); // Tu peux utiliser la fonction définie plus tôt

        const userUsername: IUser | null = await User.findById(userIdFromToken).select('username');

        logger.info(`Nouveau token créé pour l'utilisateur ${userUsername?.username} :\n accessToken: ${accessToken}`);

        return res.json({ accessToken });

        // });
    } catch (err) {
        logger.error(err);
        if (err instanceof jwt.TokenExpiredError) {
            return res.status(403).json({ error: 'Token expired' });
        }
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

        if (user.avatarUrl !== 'uploads/avatar/default.png') {
            unlink(join(avatarPath, user.avatarUrl), (err) => {
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
