import auth from '../../middleware/auth.js';
import { Router } from 'express';
import { getMenus, getApiDoc, getSectors, sitAtSector } from './ru.controller.js';
const router = Router();

router.get('/', getApiDoc);

router.get('/:ruId/sectors', auth, getSectors);

router.get('/menus', auth, getMenus);

// TODO : add a route to sit at a spécific sector
router.post('/sit', auth, sitAtSector);

export default router;
