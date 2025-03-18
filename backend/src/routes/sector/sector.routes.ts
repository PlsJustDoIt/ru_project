import { Router } from 'express';
import auth from '../../middleware/auth.js';
import { getFriendsInSector, joinSector, leaveSector } from './sector.controller.js';

const router = Router();

router.post('/join/:sectorId', auth, joinSector);

router.post('/leave/:sectorId', auth, leaveSector);

router.get('/:sectorId/friends', auth, getFriendsInSector);

export default router;
