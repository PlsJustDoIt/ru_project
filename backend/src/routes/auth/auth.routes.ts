import { Router } from 'express';
import auth from '../../middleware/auth.js';
import { deleteUser, loginUser, logoutUser, refreshUserToken, registerUser } from './auth.controller.js';

const router = Router();

router.post('/register', registerUser);

router.post('/login', loginUser);

// Pas de middleware `auth` ici : le refresh s'authentifie via le refresh token
// (dans le body), pas via l'access token qui est justement expiré à ce moment-là.
router.post('/token', refreshUserToken);

router.post('/logout', auth, logoutUser);

router.delete('/delete-account', auth, deleteUser);

export default router;
