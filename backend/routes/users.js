const express = require('express');
const auth = require('../middleware/auth');
const User = require('../models/user');
const router = express.Router();

router.get('/me', auth, async (req, res) => {
    console.log(req.body);
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        res.json(user);
    } catch (err) {
        res.status(500).send('Server error');
    }
});

router.put('/status', auth, async (req, res) => {
    const { status } = req.body;
    try {
        const user = await User.findById(req.user.id);
        user.status = status;
        await user.save();
        res.json(user);
    } catch (err) {
        res.status(500).send('Server error');
    }
});

router.get('/friends', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        res.json(user.friends);
    } catch (err) {
        res.status(500).send('Server error');
    }
});

router.post('/add-friend', auth, async (req, res) => {
    const { friendUsername } = req.body;
    try {
        const friend = await User.findOne({ username: friendUsername });
        if (!friend) return res.status(404).json({ msg: 'User not found' });
        const user = await User.findById(req.user.id);
        if (user.friends.includes(friend._id)) {
            return res.status(400).json({ msg: 'Already friends' });
        }
        user.friends.push(friend._id);
        await user.save();
        res.json(user);
    } catch (err) {
        res.status(500).send('Server error');
    }
});

router.delete('/remove-friend/:id', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        user.friends = user.friends.filter(friend => friend.toString() !== req.params.id);
        await user.save();
        res.json(user);
    } catch (err) {
        res.status(500).send('Server error');
    }
});



module.exports = router;
