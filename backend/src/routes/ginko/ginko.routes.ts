import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { getSchedules } from './ginko.controller.js';

const router = Router();
const publicGinkoLimiter = rateLimit({
    windowMs: 1 * 60 * 1000,
    limit: 10,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
});

router.get('/info', publicGinkoLimiter, getSchedules);

export default router;
