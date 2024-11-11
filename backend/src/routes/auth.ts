import express from 'express';
import jwt, { JwtPayload } from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import User from '../models/user.js';
import RefreshToken from '../models/refreshToken.js';
import { Types } from 'mongoose';
import auth from '../middleware/auth.js';

const router = express.Router();

const generateAccessToken = (id: Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_ACCESS_SECRET as jwt.Secret, { expiresIn: '15m' });
};

const generateRefreshToken = (id:Types.ObjectId) => {
    return jwt.sign({ id: id }, process.env.JWT_REFRESH_SECRET as jwt.Secret, { expiresIn: '7d' });
};

router.post('/register', async (req, res) => {
    const { username, password } = req.body;
    console.log(username, password);
    try {
        let user = await User.findOne({ username });
        if (user) return res.status(400).json({ msg: 'User already exists' });
        user = new User({ username, password });
        await user.save();
        // const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET as jwt.Secret, { expiresIn: '1h' });
        // Générer les tokens
        const accessToken = generateAccessToken(user._id);
        const refreshToken = generateRefreshToken(user._id);

        // Sauvegarder le refresh token dans la base (optionnel)
        const refreshTokenInstance = new RefreshToken({ token: refreshToken, userId: user._id, expires: new Date(Date.now() + 7*24*60*60*1000) });
        await refreshTokenInstance.save();
        res.status(201).json({ accessToken, refreshToken });
    } catch (err) {
        res.status(500).send('Server error'+err);
    }
});

router.post('/login', async (req, res) => {
    const { username, password } = req.body;
    console.log(req.body);
    try {
        const user = await User.findOne({ username });
        if (!user) return res.status(400).json({ msg: 'This user does not exists' });
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ msg: 'Incorrect password' });
        //const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET as jwt.Secret, { expiresIn: '1h' });
        // Générer les tokens
        const accessToken = generateAccessToken(user._id);
        const refreshToken = generateRefreshToken(user._id);

        // Sauvegarder le refresh token
        const refreshTokenInstance = new RefreshToken({ token: refreshToken, userId: user._id, expires: new Date(Date.now() + 7*24*60*60*1000) });
        await refreshTokenInstance.save();

        console.log(accessToken, refreshToken);
        res.json({ accessToken, refreshToken });
    } catch (err) {
        console.log(err);
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
        console.log(decoded);
        
        const userIdFromToken = decoded.id;

        // 5. Vérifier si l'ID utilisateur du token correspond à l'ID enregistré avec le refresh token
        if (existingToken.userId.toString() !== userIdFromToken) {
            return res.status(403).json({ msg: 'Refresh token does not belong to the user' });
        }

        // Générer un nouveau access token
        const accessToken = generateAccessToken(userIdFromToken); // Tu peux utiliser la fonction définie plus tôt
        res.json({ accessToken });

        // });
    } catch (err) {
        res.status(500).send('Server error: ' + err);
    }
});

router.post('/logout',auth, async (req, res) => {
    const refreshToken = req.body.refreshToken;
    try {
        await RefreshToken.findOneAndDelete({ refreshToken });
        res.json({ msg: 'Logged out' });
    } catch (err) {
        res.status(500).json({ msg: 'Server error: ' + err });
    }

});

export default router;
