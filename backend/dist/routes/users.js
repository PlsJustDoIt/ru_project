import { Router } from 'express';
import User from '../models/user.js';
import auth from '../middleware/auth.js';
const router = Router();
router.get('/me', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        res.json(user);
    }
    catch (err) {
        res.status(500).send('Could not retrieve user : ' + err);
    }
});
router.put('/status', auth, async (req, res) => {
    const { status } = req.body;
    try {
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        user.status = status;
        await user.save();
        res.json(user);
    }
    catch (err) {
        res.status(500).send('Could not update status : ' + err);
    }
});
router.get('/friends', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        if (user == null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        res.json(user.friends);
    }
    catch (err) {
        res.status(500).send('Could not retrieve friends : ' + err);
    }
});
router.post('/add-friend', auth, async (req, res) => {
    const { friendUsername } = req.body;
    try {
        const friend = await User.findOne({ username: friendUsername });
        if (!friend)
            return res.status(404).json({ msg: 'Friend not found' });
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        if (user.friends.includes(friend._id)) {
            return res.status(400).json({ msg: 'Already friends' });
        }
        user.friends.push(friend._id);
        await user.save();
        res.json(user);
    }
    catch (err) {
        res.status(500).send('Server error : ' + err);
    }
});
router.delete('/remove-friend/:id', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (user == null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        user.friends = user.friends.filter((friend) => friend.toString() !== req.params.id);
        await user.save();
        res.json(user);
    }
    catch (err) {
        res.status(500).send('Server error : ' + err);
    }
});
export default router;
