import jwt from 'jsonwebtoken';

import { Request, Response, NextFunction } from 'express';
import logger from '../utils/logger.js';
import { jwtAccessSecret } from '../config.js';

export default function (req: Request, res: Response, next: NextFunction): void {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
        logger.error('No token, authorization denied');
        res.status(401).json({ error: 'No token, authorization denied' });
        return;
    }
    try {
        const decoded = jwt.verify(token, jwtAccessSecret);
        if (typeof decoded === 'string') {
            logger.error('Invalid token');
            throw new Error('Invalid token');
        }
        req.user = decoded;
        next();
        return;
    } catch (err: unknown) {
        logger.error(err);
        // Ne pas renvoyer l'objet d'erreur brut au client (fuite d'info interne)
        res.status(403).json({ error: 'Invalid or expired token' });
    }
};
