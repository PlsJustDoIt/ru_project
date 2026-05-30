import { Router } from 'express';
import { getSchedules } from './ginko.controller.js';

const router = Router();

router.get('/info', getSchedules);

export default router;
