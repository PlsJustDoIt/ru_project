import jwt from 'jsonwebtoken';

import { Request, Response, NextFunction } from 'express';
import logger from '../services/logger.js';

export default function (req: Request, res: Response, next: NextFunction): void {
    if (req.url.includes('/token')) {
        next();
        return;
    }
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
        logger.error('No token, authorization denied');
        res.status(401).json({ error: 'No token, authorization denied' });
        return;
    }
    try {
        const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET as jwt.Secret);
        if (typeof decoded === 'string') { // token expired
            logger.error('Invalid token');
            throw new Error('Invalid token');
        }
        req.user = decoded;
        next();
        return;
    } catch (err: unknown) {
        logger.error(err);
        res.status(403).json({ error: err });
    }
};
