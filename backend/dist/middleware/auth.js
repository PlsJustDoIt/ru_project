import jwt from 'jsonwebtoken';
export default function (req, res, next) {
    const token = req.header('x-auth-token');
    if (token == null) {
        res.status(401).json({ msg: 'No token, authorization denied' });
    }
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.body.user = decoded;
        next();
    }
    catch (err) {
        res.status(401).json({ error: err });
    }
}
;
