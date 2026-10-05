import jwt from 'jsonwebtoken';

import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger.js';
import { jwtAccessSecret } from '../config.js';

/**
 * Variante de `auth` pour les routes ouvertes aux invités : sans token, la
 * requête passe en anonyme (`req.user` non défini). Un token présent mais
 * invalide/expiré est refusé (403), comme `auth`, pour que le client
 * rafraîchisse sa session au lieu d'agir silencieusement en anonyme.
 */
export default function optionalAuth(req: Request, res: Response, next: NextFunction): void {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
        next();
        return;
    }
    try {
        const decoded = jwt.verify(token, jwtAccessSecret);
        if (typeof decoded === 'string') {
            throw new Error('Invalid token');
        }
        req.user = decoded;
        next();
    } catch (err: unknown) {
        logger.error(err);
        res.status(403).json({ error: 'Invalid or expired token' });
    }
}
