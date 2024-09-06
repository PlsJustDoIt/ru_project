import jwt from 'jsonwebtoken';

export default function(req:any, res:any, next: any):any {
    const token:string = req.header('x-auth-token');
    if (!token) return res.status(401).json({ msg: 'No token, authorization denied' });
    try {
        const decoded:jwt.JwtPayload | string = jwt.verify(token, process.env.JWT_SECRET as jwt.Secret);
        req.body.user = decoded;
        next();
    } catch (err:any) {
        res.status(401).json({ msg: 'Token is not valid' });
    }
};
