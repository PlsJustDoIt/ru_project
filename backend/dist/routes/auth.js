import express from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import User from '../models/user.js';
const router = express.Router();
router.post('/register', async (req, res) => {
    const { username, password } = req.body;
    console.log(username, password);
    try {
        let user = await User.findOne({ username });
        if (user)
            return res.status(400).json({ msg: 'User already exists' });
        user = new User({ username, password });
        await user.save();
        const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
        res.json({ token });
    }
    catch (err) {
        res.status(500).send('Server error' + err);
    }
});
router.post('/login', async (req, res) => {
    const { username, password } = req.body;
    console.log(req.body);
    try {
        const user = await User.findOne({ username });
        if (!user)
            return res.status(400).json({ msg: 'This user does not exists' });
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch)
            return res.status(400).json({ msg: 'Incorrect password' });
        const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '1h' });
        console.log(token);
        res.json({ token });
    }
    catch (err) {
        res.status(500).send('Server error ' + err);
    }
});
export default router;
