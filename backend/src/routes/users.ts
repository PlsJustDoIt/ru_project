import { Router, Request, Response } from 'express';
import User, { IUser } from '../models/user.js';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
const router = Router();

router.get('/me', auth, async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        res.json(user);
    } catch (err: unknown) {
        res.status(500).send('Could not retrieve user : ' + err);
    }
});

const TEXT_MIN_LENGTH = 3;
const TEXT_MAX_LENGTH = 32;

router.put('/update', auth, async (req: Request, res: Response) => {
    try {
        let username = req.body.username;
        let password = req.body.password;

        // username and password : min 3 caractères, max 32 char and not empty and not null and not only spaces

        if (!username || !password) {
            logger.error('Username or password field dosn\'t exists');
            return res.status(400).json({ error: 'Username or password dosn\'t exists' });
        }

        username = username.trim();
        password = password.trim();

        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        // check if new username already exists
        const testUser = await User.findOne({ username });
        if (testUser) res.status(400).json({ error: 'User already exists' });

        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }

        const user_updated = req.body;

        user.password = user_updated.password;
        user.username = user_updated.username;
        user.status = user_updated.status;
        user.friends = user_updated.friends;

        await user.save();

        res.send('User updated');
    } catch (err: unknown) {
        logger.error(`Could not update user : ${err}`);
        res.status(500).send({ error: `Could not update user : ${err} ` });
    }
});

// update only username, we need username
router.put('/update-username', auth, async (req: Request, res: Response) => {
    try {
        // test validation username
        let username = req.body.username;
        if (!username) {
            logger.error('Username field dosn\'t exists');
            return res.status(400).json({ error: 'Username dosn\'t exists' });
        }
        username = username.trim();
        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        const testUser = await User.findOne({ username });
        if (testUser) res.status(400).json({ error: 'User already exists' });

        const user = await User.findById(req.user.id);

        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }
        user.username = username;

        await user.save();

        res.send('Username updated');
    } catch (err: unknown) {
        logger.error(`Could not update username : ${err}`);
        res.status(500).send({ error: `Could not update username : ${err} ` });
    }
});

// update only password, we need password
router.put('/update-password', auth, async (req: Request, res: Response) => {
    try {
        // test validation password
        let password = req.body.password;
        if (!password) {
            logger.error('Password field dosn\'t exists');
            return res.status(400).json({ error: 'Password dosn\'t exists' });
        }
        password = password.trim();
        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        const user = await User.findById(req.user.id);

        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }

        user.password = password;

        await user.save();

        res.send('Password updated');
    } catch (err: unknown) {
        logger.error(`Could not update password : ${err}`);
        res.status(500).send({ error: `Could not update password : ${err} ` });
    }
});

// update only status, we need status
router.put('/update-status', auth, async (req: Request, res: Response) => {
    try {
        // test validation status
        const { status } = req.body;
        if (!status) {
            logger.error('Status field dosn\'t exists');
            return res.status(400).json({ error: 'Status dosn\'t exists' });
        }

        const user = await User.findById(req.user.id);

        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }

        user.status = status;

        await user.save();

        res.send('Status updated');
    } catch (err: unknown) {
        logger.error(`Could not update status : ${err}`);
        res.status(500).send({ error: `Could not update status : ${err} ` });
    }
});

router.get('/friends', auth, async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id).populate<{ friends: IUser[] }>('friends', 'username status avatarUrl id');
        if (user == null) {
            return res.status(404).json({ msg: 'User not found' });
        }
        const friends = user.friends.map(friend => ({
            username: friend.username,
            status: friend.status,
            avatarUrl: friend.avatarUrl,
            id: friend._id,
        }));

        logger.info('User friends : ' + friends);
        res.json(friends);
    } catch (err: unknown) {
        res.status(500).send('Could not retrieve friends : ' + err);
    }
});

router.get('/search', auth, async (req: Request, res: Response) => {
    const query = req.body.query;
    if (!query) {
        return res.status(400).json({ error: 'No query provided' });
    }
    const searchItem = new RegExp(query, 'i'); // case-insensitive search

    try {
        const foundUsers = await User.find({ username: searchItem }).select('id username avatarUrl').limit(6).exec();

        if (foundUsers.length === 0) {
            return res.status(404).json({ msg: 'No users found' });
        }
        const minimisedUsers = foundUsers.map(user => ({
            username: user.username,
            avatarUrl: user.avatarUrl,
            status: user.status,
            id: user._id,
        }));
        res.send(minimisedUsers);
    } catch (err: unknown) {
        logger.error('Could not search for user: ' + err);
        res.status(500).send({ Error: 'Could not search for user' });
    }
});

router.post('/add-friend', auth, async (req: Request, res: Response) => {
    const { username } = req.body;
    try {
        const friend = await User.findOne({ username: username });
        if (!friend) return res.status(404).json({ msg: 'Friend not found' });
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }
        if (user._id == friend._id) {
            return res.status(400).json({ error: 'Cannot add yourself' });
        }
        if (user.friends.includes(friend._id)) {
            return res.status(400).json({ error: 'Already friends' });
        }
        user.friends.push(friend._id);
        await user.save();
        logger.info('friends list : ' + user.friends);
        res.json(user);
    } catch (err: unknown) {
        res.status(500).send('Server error : ' + err);
    }
});

router.delete('/remove-friend', auth, async (req: Request, res: Response) => {
    try {
        const friendId = req.body.friendId;
        if (!friendId) {
            return res.status(400).json({ error: 'No friendId provided' });
        }
        const user = await User.findById(req.user.id);
        if (user == null) {
            return res.status(404).json({ error: 'User not found' });
        }
        const index = user.friends.findIndex((friend: { toString: () => string }) => friend.toString() === friendId);
        if (index !== -1) {
            user.friends.splice(index, 1);
        }
        await user.save();
        res.json(user);
    } catch (err: unknown) {
        res.status(500).send('Server error : ' + err);
    }
});

export default router;
