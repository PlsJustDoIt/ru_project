import jwt from 'jsonwebtoken';

import { Request, Response, NextFunction } from 'express';

export default function(req: Request, res: Response, next: NextFunction): void {
    const authHeader = req.headers['authorization']; // Utilisation de l'en-tête Authorization
    const token = authHeader && authHeader.split(' ')[1];
    //const token = req.header('x-auth-token'); // pas ouf 
    if (token == null || token == undefined) {
        res.status(401).json({ error: 'No token, authorization denied' });
        return;
    } 
    try {
        const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET as jwt.Secret);
        if (typeof decoded === 'string') {
            throw new Error('Invalid token');
        }
        req.user = decoded;
        next();
    } catch (err:unknown) {
        res.status(403).json({ error: err });
    }
};
