import jwt from 'jsonwebtoken';

import { Request, Response, NextFunction } from 'express';

export default function(req: Request, res: Response, next: NextFunction): void {
    const token = req.header('x-auth-token');
    if (token == null) {
        res.status(401).json({ msg: 'No token, authorization denied' });
    } 
    try {
        const decoded = jwt.verify(token!, process.env.JWT_SECRET as jwt.Secret);
        if (typeof decoded === 'string') {
            throw new Error('Invalid token');
        }
        req.user = decoded;
        next();
    } catch (err:unknown) {
        res.status(401).json({ error: err });
    }
};
