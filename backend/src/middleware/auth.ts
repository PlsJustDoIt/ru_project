import jwt from 'jsonwebtoken';

import { Request, Response, NextFunction } from 'express';
import logger from '../services/logger.js';

export default function(req: Request, res: Response, next: NextFunction): void {
    if (req.url.includes('/token')) {
        return next();
    }
    const authHeader = req.headers['authorization']; // Utilisation de l'en-tête Authorization
    const token = authHeader && authHeader.split(' ')[1];
    if (token == null || token == undefined) {
        logger.error('No token, authorization denied');
        res.status(401).json({ error: 'No token, authorization denied' });
        return;
    } 
    try {
        const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET as jwt.Secret);
        logger.info('decoded: ' + JSON.stringify(decoded));
        if (typeof decoded === 'string') { // token expired
            logger.error('Invalid token');
            throw new Error('Invalid token');
        }
        req.user = decoded;
        next();
    } catch (err:unknown) {
        logger.error(err);
        res.status(403).json({ error: err });
    }
};
