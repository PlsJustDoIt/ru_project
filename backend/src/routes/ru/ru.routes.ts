import auth from '../../middleware/auth.js';
import { Router } from 'express';
import { getMenus, getApiDoc, getSectors, getRestaurants, getSectorsSessions, getAllSectorsSessions, getRestaurantInfo, getRestaurantByOwnId } from './ru.controller.js';
const router = Router();

router.get('/', getApiDoc);

router.get('/:restaurantId/sectors', getSectors);

router.get('/menus', getMenus);

router.get('/restaurants', getRestaurants);

// Restent protégés : sessions = identités d'utilisateurs
router.get('/:restaurantId/sectors-sessions', auth, getSectorsSessions);
router.get('/:restaurantId/sectors-sessions/all', auth, getAllSectorsSessions);

router.get('/:restaurantId/info', getRestaurantInfo);

router.get('/:restaurantId', getRestaurantByOwnId);

export default router;
