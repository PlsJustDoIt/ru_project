import { Router } from 'express';
import { getSchedules } from './ginko.controller.js';
import auth from '../../middleware/auth.js';

const router = Router();

router.get('/info', auth, getSchedules);

export default router;
