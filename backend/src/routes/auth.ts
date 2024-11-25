import express from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import User from '../models/user.js';
import RefreshToken from '../models/refreshToken.js';
import { Types } from 'mongoose';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import { error } from 'console';
const router = express.Router();

const TEXT_MIN_LENGTH = 3;
const TEXT_MAX_LENGTH = 32;

const generateAccessToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_ACCESS_SECRET as jwt.Secret, { expiresIn: '15m' });
};

const generateRefreshToken = (id:Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_REFRESH_SECRET as jwt.Secret, { expiresIn: '7d' });
};

router.post('/register', async (req, res) => {
    let { username, password } = req.body;
    try {
        //username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces 
        if (!username || !password) {
            logger.error('Username or password field dosn\'t exists');
            res.status(400).json({ error: 'Username or password dosn\'t exists' });
        }

        username = username.trim();
        password = password.trim();

        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH ) {
            logger.error(`Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH ) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        let user = await User.findOne({ username });
        if (user)  res.status(400).json({ error: 'User already exists' });
        user = new User({ username, password });
        await user.save();
        // const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET as jwt.Secret, { expiresIn: '1h' });
        // Générer les tokens
        const accessToken = generateAccessToken(user._id);
        const refreshToken = generateRefreshToken(user._id);

        // Sauvegarder le refresh token dans la base (optionnel)
        const refreshTokenInstance = new RefreshToken({ token: refreshToken, userId: user._id, expires: new Date(Date.now() + 7*24*60*60*1000) });
        await refreshTokenInstance.save();
        logger.info(`Engistrement de l'utilisateur ${username}`);
        res.status(201).json({ accessToken, refreshToken });
    } catch (err) {
        logger.error(err);
        res.status(500).send('Server error'+err);
    }
});

router.post('/login', async (req, res) => {

    let { username, password } = req.body;
    
    try {
        //username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces 

        if (!username || !password) {
            logger.error('Username or password field dosn\'t exists');
            return res.status(400).json({ error: 'Username or password dosn\'t exists' });
        }

        username = username.trim();
        password = password.trim();

        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH ) {
            logger.error(`Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH ) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        const user = await User.findOne({ username });
        if (!user) return res.status(400).json({ error: 'This user does not exists' });
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ error: 'Incorrect password' });
        //const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET as jwt.Secret, { expiresIn: '1h' });
        // Générer les tokens
        const accessToken = generateAccessToken(user._id);
        const refreshToken = generateRefreshToken(user._id);

        // Sauvegarder le refresh token
        const refreshTokenInstance = new RefreshToken({ token: refreshToken, userId: user._id, expires: new Date(Date.now() + 7*24*60*60*1000) });
        await refreshTokenInstance.save();

        logger.info(`Connexion de l'utilisateur ${username}`);

        res.json({ accessToken, refreshToken });
    } catch (err) {
        logger.error(err);
        res.status(500).send('Server error '+err);
    }
});

router.post('/token',auth, async (req, res) => {
    const refreshToken = req.body.refreshToken;
    try {
        const existingToken = await RefreshToken.findOne({ refreshToken });
        if (!existingToken) return res.status(403).json({ msg: 'Invalid refresh token' });

         // Vérifier si le token est expiré (optionnel, mais si tu stockes l'expiration dans la base)
        if (existingToken.expires.getTime() < Date.now()) {
            await RefreshToken.findOneAndDelete({ refreshToken });
            // peut etre refaire un refresh token au lieu de renvoyer erreur ???
            return res.status(403).json({ msg: 'Refresh token expired' });
        }

        // Vérifier si le refresh token est valide
        const decoded =  jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET as jwt.Secret) as JwtPayload;
        logger.info(decoded);
        
        const userIdFromToken = decoded.id;

        // 5. Vérifier si l'ID utilisateur du token correspond à l'ID enregistré avec le refresh token
        if (existingToken.userId.toString() !== userIdFromToken) {
            return res.status(403).json({ error: 'Refresh token does not belong to the user' });
        }

        // Générer un nouveau access token
        const accessToken = generateAccessToken(userIdFromToken); // Tu peux utiliser la fonction définie plus tôt
        
        logger.info(`Nouveau token créé pour l'utilisateur ${req.user} :\n accessToken: ${accessToken}`);

        res.json({ accessToken });

        // });
    } catch (err) {
        logger.error(err);
        res.status(500).send('Server error: ' + err);
    }
});

router.post('/logout',auth, async (req, res) => {
    const refreshToken = req.body.refreshToken;
    try {
        await RefreshToken.findOneAndDelete({ refreshToken });
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'problem with the middleware' });
        }
        logger.info(`Déconnexion de l'utilisateur ${user.username}`);
        res.json({ msg: 'Logged out' });
    } catch (err) {
        logger.error(err);
        res.status(500).json({ error: 'Server error: ' + err });
    }
});

export default router;
