import { Router } from 'express';
import { getSchedules } from './ginko.controller.js';
import auth from '../../middleware/auth.js';
import { isProduction } from '../../config.js';
import { Request, Response } from 'express';

const router = Router();

router.get('/info', auth, (req: Request, res: Response) => getSchedules(req, res, isProduction));

export default router;
