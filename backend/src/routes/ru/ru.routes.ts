import auth from '../../middleware/auth.js';
import { Router } from 'express';
import { getMenus, getApiDoc, getSectors, getRestaurants, getSectorsSessions } from './ru.controller.js';
const router = Router();

router.get('/', getApiDoc);

router.get('/:restaurantId/sectors', auth, getSectors);

router.get('/menus', auth, getMenus);

router.get('/restaurants', auth, getRestaurants);

router.get('/:restaurantId/sectors-sessions', auth, getSectorsSessions);

export default router;
