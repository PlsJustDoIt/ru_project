import { JwtPayload } from 'jsonwebtoken';

declare global {
  namespace Express {
    interface Request {
      user: JwtPayload; // Déclarez `user` comme étant de type `JwtPayload` ou un autre type que vous utilisez
    }
  }
}
