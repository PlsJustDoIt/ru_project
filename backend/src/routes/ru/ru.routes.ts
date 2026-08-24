import auth from '../../middleware/auth.js';
import { Router } from 'express';
import { getMenus, getApiDoc, getSectors, getRestaurants, getSectorsSessions, getAllSectorsSessions, getRestaurantInfo, getRestaurantByOwnId, syncRestaurants } from './ru.controller.js';
const router = Router();

router.get('/', getApiDoc);

router.get('/:restaurantId/sectors', getSectors);

router.get('/menus', getMenus);

router.get('/restaurants', getRestaurants);

// Re-sync forcé du catalogue CROUS (sinon automatique tous les 3 mois)
router.post('/restaurants/sync', auth, syncRestaurants);

// Restent protégés : sessions = identités d'utilisateurs
router.get('/:restaurantId/sectors-sessions', auth, getSectorsSessions);
router.get('/:restaurantId/sectors-sessions/all', auth, getAllSectorsSessions);

router.get('/:restaurantId/info', getRestaurantInfo);

router.get('/:restaurantId', getRestaurantByOwnId);

export default router;
