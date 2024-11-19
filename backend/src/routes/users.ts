import { Router,Request,Response } from 'express';
import User from '../models/user.js';
import auth from '../middleware/auth.js';
const router = Router();

router.get('/me', auth, async (req:Request, res:Response) => {

    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        res.json(user);
    } catch (err:unknown) {
        res.status(500).send('Could not retrieve user : '+err);
    }
});



router.put('/update', auth, async (req:Request, res:Response) => {

    try {
        //username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces 
        if (!req.body.username || !req.body.password || req.body.username.length < 3 || req.body.username.length > 32 || req.body.password.length < 3 || req.body.password.length > 32 || !req.body.username.replace(/\s/g, '').length || !req.body.password.replace(/\s/g, '').length) {
            return res.status(400).json({ msg: 'Invalid username or password' });
        }
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ msg: 'User not found' });
        }

        const user_updated = req.body;

        user.password = user_updated.password;
        user.username = user_updated.username;
        user.status = user_updated.status;
        user.friends = user_updated.friends;

        await user.save();

        res.send('User updated');
    } catch (err:unknown) {
        res.status(500).send('Could not update user : '+err);
    }

});



//TODO : à revoir le modèle
router.put('/status', auth, async (req:Request, res:Response) => {
    const { status } = req.body;
    try {
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        user.status = status;
        await user.save();
        res.json(user);
    } catch (err:unknown) {
        res.status(500).send('Could not update status : '+err);
    }
});

router.get('/friends', auth, async (req:Request, res:Response) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        if (user == null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        res.json(user.friends);
    } catch (err:unknown) {
        res.status(500).send('Could not retrieve friends : '+err);
    }
});

router.post('/add-friend', auth, async (req:Request, res:Response) => {
    const { friendUsername } = req.body;
    try {
        const friend = await User.findOne({ username: friendUsername });
        if (!friend) return res.status(404).json({ msg: 'Friend not found' });
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
    } catch (err:unknown) {
        res.status(500).send('Server error : '+err);
    }
});

router.delete('/remove-friend/:id', auth, async (req:Request, res:Response) => {
    try {
        const user = await User.findById(req.user.id);
        if (user == null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        user.friends = user.friends.filter((friend: { toString: () => string; }) => friend.toString() !== req.params.id);
        await user.save();
        res.json(user);
    } catch (err:unknown) {
        res.status(500).send('Server error : '+err);
    }
});


export default router;
