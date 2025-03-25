import { Router } from 'express';
import auth from '../../middleware/auth.js';
import { deleteUser, loginUser, logoutUser, refreshUserToken, registerUser } from './auth.controller.js';

const router = Router();

router.post('/register', registerUser);

router.post('/login', loginUser);

router.post('/token', auth, refreshUserToken);

router.post('/logout', auth, logoutUser);

router.delete('/delete-account', auth, deleteUser);

export default router;
