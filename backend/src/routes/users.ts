import { Router, Request, Response } from 'express';
import User, { IUser } from '../models/user.js';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import { uploadAvatar, convertAndCompressAvatar } from '../services/multer.js';
import bcrypt from 'bcrypt';
const router = Router();

router.get('/me', auth, async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        return res.json({ user: user });
    } catch (err: unknown) {
        logger.error('Could not retrieve user : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
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
        if (testUser) return res.status(400).json({ error: 'User already exists' });

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

        return res.json({ message: 'User updated' });
    } catch (err: unknown) {
        logger.error(`Could not update user : ${err}`);
        return res.status(500).json({ error: `Could not update user : ${err} ` });
    }
});

// update only username, we need username
router.put('/update-username', auth, async (req: Request, res: Response) => {
    try {
        // test validation username
        let username = req.body.username;
        if (!username) {
            return res.status(400).json({ error: 'Username dosn\'t exists' });
        }
        username = username.trim();
        if (username.length < TEXT_MIN_LENGTH || username.length > TEXT_MAX_LENGTH) {
            return res.status(400).json({ error: `Invalid length for username (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)` });
        }

        const testUser = await User.findOne({ username });
        if (testUser) return res.status(400).json({ error: 'A user with this username already exists' });

        const user = await User.findById(req.user.id);

        if (user === null) {
            logger.error('User not found');
            return res.status(500).json({ error: 'An error has occured' });
        }
        user.username = username;

        await user.save();

        return res.json({ username: username });
    } catch (err: unknown) {
        logger.error(`Could not update username : ${err}`);
        return res.status(500).json({ error: `An error has occured` });
    }
});

// update only password, we need password
router.put('/update-password', auth, async (req: Request, res: Response) => {
    try {
        // test validation password
        let password = req.body.password;
        const oldPassword = req.body.oldPassword;

        if (!oldPassword) {
            logger.error('Old password field dosn\'t exists');
            return res.status(400).json({ error: { message: 'Old password dosn\'t exists', field: 'oldPassword' } });
        }

        if (!password) {
            logger.error('Password field dosn\'t exists');
            return res.status(400).json({ error: { message: 'Password dosn\'t exists', field: 'password' } });
        }
        password = password.trim();
        if (password.length < TEXT_MIN_LENGTH || password.length > TEXT_MAX_LENGTH) {
            logger.error(`Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`);
            return res.status(400).json({ error: { message: `Invalid length for password (length must be between ${TEXT_MIN_LENGTH} and ${TEXT_MAX_LENGTH} characters)`, field: 'password' } });
        }

        const user = await User.findById(req.user.id);

        if (user === null) {
            logger.error('User not found');
            return res.status(500).json({ error: 'An error has occured' });
        }

        const isMatch = await bcrypt.compare(oldPassword, user.password);
        if (!isMatch) {
            logger.error('Incorrect old password');
            return res.status(400).json({ error: { message: 'Incorrect old password', field: 'oldPassword' } });
        }

        user.password = password; // le mot de passe est hashé dans le pre save du model user tkt

        await user.save();

        return res.json({ message: 'Password updated' });
    } catch (err: unknown) {
        logger.error(`Could not update password : ${err}`);
        return res.status(500).json({ error: `An error has occured` });
    }
});

// update only status, we need status
router.put('/update-status', auth, async (req: Request, res: Response) => {
    try {
        const status = req.body.status;

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

        return res.json({ status: user.status });
    } catch (err: unknown) {
        logger.error(`Could not update status : ${err}`);
        return res.status(500).json({ error: `An error has occured` });
    }
});

router.put('/update-profile-picture', auth, uploadAvatar.single('avatar'), convertAndCompressAvatar, async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id);

        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        logger.info(req.file);
        const avatarUrl = 'uploads/avatar/' + req.file.filename;
        user.avatarUrl = avatarUrl;

        await user.save();

        return res.json({ avatarUrl: avatarUrl });
    } catch (err: unknown) {
        logger.error('Could not update profile picture : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

router.get('/friends', auth, async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id).populate<{ friends: IUser[] }>('friends', 'username status avatarUrl id');
        if (user == null) {
            return res.status(404).json({ error: 'User not found' });
        }

        const friends = user.friends.map(friend => ({
            username: friend.username,
            status: friend.status,
            avatarUrl: friend.avatarUrl,
            id: friend._id,
        }));

        logger.info('User friends : ' + friends);
        return res.json({ friends: friends });
    } catch (err: unknown) {
        logger.error('Could not retrieve friends : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

// search for users
router.get('/search', auth, async (req: Request, res: Response) => {
    try {
        const query = req.query.query;
        if (!query || typeof query !== 'string' || query.trim().length < 3) {
            logger.error('No string query provided');
            return res.status(400).json({ error: 'No query provided' });
        }
        if (query.trim().length < 3) {
            logger.error('Search username must be at least 3 characters');
            return res.status(400).json({ error: 'Search username must be at least 3 characters' });
        }

        const searchTerm = query.toLowerCase().trim();
        const searchItem = new RegExp(query, 'i');

        const foundUsers = await User.find({ username: searchItem })
            .select('id username avatarUrl status')
            .limit(10);

        if (foundUsers.length === 0) {
            return res.status(404).json({ error: 'No users found' });
        }

        const searchResults = foundUsers.map((user) => {
            const username = user.username.toLowerCase();
            let relevanceScore = 0;

            // Exact match gets highest score
            if (username === searchTerm) {
                relevanceScore = 100;
            } else if (username.startsWith(searchTerm)) { // Starts with search term
                relevanceScore = 75;
            } else if (username.includes(searchTerm)) { // Contains search term
                relevanceScore = 50;
            } else { // Calculate distance for partial matches
                const distance = levenshteinDistance(username, searchTerm);
                relevanceScore = Math.max(0, 100 - (distance * 10));
            }

            return {
                user: {
                    username: user.username,
                    avatarUrl: user.avatarUrl,
                    status: user.status,
                    id: user._id,
                },
                relevanceScore: relevanceScore,
            };
        }).sort((a, b) => b.relevanceScore - a.relevanceScore);
        logger.info('Search results : ', searchResults);
        return res.json({ results: searchResults });
    } catch (err: unknown) {
        logger.error('Could not search for user: ' + err);
        return res.status(500).json({ Error: 'An error has occured' });
    }
});

// Fonction utilitaire pour calculer la distance de Levenshtein
function levenshteinDistance(str1: string, str2: string): number {
    const m = str1.length;
    const n = str2.length;
    const dp: number[][] = Array(m + 1).fill(null).map(() => Array(n + 1).fill(0));

    for (let i = 0; i <= m; i++) {
        dp[i][0] = i;
    }
    for (let j = 0; j <= n; j++) {
        dp[0][j] = j;
    }

    for (let i = 1; i <= m; i++) {
        for (let j = 1; j <= n; j++) {
            if (str1[i - 1] === str2[j - 1]) {
                dp[i][j] = dp[i - 1][j - 1];
            } else {
                dp[i][j] = Math.min(
                    dp[i - 1][j - 1] + 1,
                    dp[i - 1][j] + 1,
                    dp[i][j - 1] + 1,
                );
            }
        }
    }

    return dp[m][n];
}

router.post('/add-friend', auth, async (req: Request, res: Response) => {
    const { username } = req.body;
    try {
        const friend = await User.findOne({ username: username });
        if (!friend) return res.status(404).json({ error: 'Friend not found' });
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }

        if (user._id.equals(friend._id)) {
            return res.status(400).json({ error: 'Cannot add yourself' });
        }

        if (user.friends.some(f => f._id.equals(friend._id))) {
            return res.status(400).json({ error: 'Already friends' });
        }
        user.friends.push(friend._id);
        await user.save();
        logger.info('friends list : ' + user.friends);
        return res.json({ message: 'Friend added', friend: friend });
    } catch (err: unknown) {
        logger.error('Could not add friend : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
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
        return res.json({ user: user });
    } catch (err: unknown) {
        logger.error('Could not remove friend : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
});

export default router;
