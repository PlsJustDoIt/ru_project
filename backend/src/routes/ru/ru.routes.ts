import auth from '../../middleware/auth.js';
import { Router } from 'express';
import { getMenus, getApiDoc, getSectors } from './ru.controller.js';
const router = Router();

router.get('/', getApiDoc);

router.get('/:ruId/sectors', auth, getSectors);

router.get('/menus', auth, getMenus);

export default router;
