import { Router } from 'express';
import auth from '../../middleware/auth.js';
import { acceptFriendRequest, declineFriendRequest, getFriendRequests, getUserFriends, getUserInformation, removeFriend, searchUsers, sendBugReport, sendFriendRequest, updatePassword, updateProfilePicture, updateStatus, updateUsername } from './user.controller.js';
import { convertAndCompress, uploadAvatar, uploadBugReport } from '../../utils/multer.js';
const router = Router();

router.get('/me', auth, getUserInformation);

// update only username, we need username
router.put('/update-username', auth, updateUsername);

// update only password, we need password
router.put('/update-password', auth, updatePassword);

// update only status, we need status
router.put('/update-status', auth, updateStatus);

router.put('/update-profile-picture', auth, uploadAvatar.single('avatar'), convertAndCompress, updateProfilePicture);

router.get('/friends', auth, getUserFriends);

// search for users
router.get('/search', auth, searchUsers);

router.delete('/remove-friend', auth, removeFriend);

router.get('/friend-requests', auth, getFriendRequests);

router.post('/send-friend-request', auth, sendFriendRequest);
router.post('accept-friend-request', auth, acceptFriendRequest);
router.post('/decline-friend-request', auth, declineFriendRequest);
router.post('/send-bug-report', auth, uploadBugReport.single('screenshot'), convertAndCompress, sendBugReport);

export default router;
