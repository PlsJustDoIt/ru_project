import User, { IUser } from '../../models/user.js';
import { Request, Response } from 'express';
import logger from '../../utils/logger.js';
import { compare } from 'bcrypt';
import { getUserByUsername, levenshteinDistance, TEXT_MAX_LENGTH, TEXT_MIN_LENGTH } from './user.service.js';
import FriendRequest from '../../models/friendsRequest.js';
import BugReport from '../../models/bugReport.js';
import { join } from 'path';

const getUserInformation = async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id).populate('friends', 'username status');
        return res.json({ user: user });
    } catch (err: unknown) {
        logger.error('Could not retrieve user : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
};

const updateUsername = async (req: Request, res: Response) => {
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

        const testUser = await getUserByUsername(username);
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
};

// TODO : à refaire parce que c'est pas propre
const updatePassword = async (req: Request, res: Response) => {
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

        const isMatch = await compare(oldPassword, user.password);
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
};

const updateStatus = async (req: Request, res: Response) => {
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
};

const updateProfilePicture = async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id);

        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        logger.info(req.file);
        const avatarUrl = join('uploads/avatar/', req.file.filename);
        user.avatarUrl = avatarUrl;

        await user.save();

        return res.json({ avatarUrl: avatarUrl });
    } catch (err: unknown) {
        logger.error('Could not update profile picture : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
};

const getUserFriends = async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id).populate<{ friends: IUser[] }>('friends', 'username status avatarUrl');
        if (user == null) {
            return res.status(404).json({ error: 'User not found' });
        }

        const friends = user.friends.map(friend => ({
            username: friend.username,
            status: friend.status,
            avatarUrl: friend.avatarUrl,
            _id: friend._id,
        }));

        logger.info('User friends : %o', friends);
        return res.json({ friends: friends });
    } catch (err: unknown) {
        logger.error('Could not retrieve friends : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
};

const searchUsers = async (req: Request, res: Response) => { // TODO : factoriser ce code dans le service
    try {
        const query = req.query.query;
        if (!query || typeof query !== 'string') {
            logger.error('No string query provided');
            return res.status(400).json({ error: 'No query provided' });
        }
        if (query.trim().length < 3) {
            logger.error('Search username must be at least 3 characters');
            return res.status(400).json({ error: 'Search username must be at least 3 characters' });
        }

        const searchTerm = query.toLowerCase().trim();
        const searchItem = new RegExp(query, 'i');

        let foundUsers = await User.find({ username: searchItem })
            .select('id username avatarUrl status')
            .limit(10);

        if (foundUsers.length === 0) {
            return res.status(404).json({ error: 'No users found' });
        }

        const existingRequests = await FriendRequest.find({
            sender: req.user.id,
            status: 'pending',
        }).select('receiver');

        const requestedIds = new Set(
            existingRequests.map(req => req.receiver.toString()),
        );

        foundUsers = foundUsers.filter(u => !requestedIds.has(u._id.toString()));

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
};

const removeFriend = async (req: Request, res: Response) => {
    try {
        const friendId = req.body.friendId;
        if (!friendId) {
            return res.status(400).json({ error: 'No friendId provided' });
        }

        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const friend = await User.findById(friendId);
        if (!friend) {
            return res.status(404).json({ error: 'Friend not found' });
        }

        // Remove user from friend's friends list
        const userIndexInFriendList = friend.friends.findIndex((f: { toString: () => string }) => f.toString() === user._id.toString());
        if (userIndexInFriendList !== -1) {
            friend.friends[userIndexInFriendList] = friend.friends[friend.friends.length - 1];
            friend.friends.pop();
            await friend.save();
        }

        // Remove friend from user's friends list
        const friendIndexInUserList = user.friends.findIndex((f: { toString: () => string }) => f.toString() === friendId);
        if (friendIndexInUserList !== -1) {
            user.friends[friendIndexInUserList] = user.friends[user.friends.length - 1];
            user.friends.pop();
            await user.save();
        }

        return res.json({ message: 'Friend removed successfully', user: user });
    } catch (err: unknown) {
        logger.error('Could not remove friend : ' + err);
        return res.status(500).json({ error: 'An error has occurred' });
    }
};

const getFriendRequests = async (req: Request, res: Response) => {
    try {
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }
        const resFriendRequests = await FriendRequest.find({ receiver: user._id }).populate<{ sender: IUser }>('sender', 'username avatarUrl');

        logger.info('res : %o', resFriendRequests);

        const friendRequests = resFriendRequests.map(request => ({
            id: request._id,
            sender: {
                username: request.sender.username,
                avatarUrl: request.sender.avatarUrl,
                id: request.sender._id,
            },
            createdAt: request.createdAt,
            status: request.status,
        }));

        return res.json({ friendRequests });
    } catch (err: unknown) {
        logger.error('Could not retrieve friends requests : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
};

const sendFriendRequest = async (req: Request, res: Response) => {
    try {
        const { username } = req.body;
        const sender = await User.findById(req.user.id);
        if (sender === null) {
            logger.error('User not found');
            return res.status(404).json({ error: 'User not found' });
        }
        const receiver = await User.findOne({ username: username });
        if (receiver === null) {
            logger.error('Receiver not found');
            return res.status(404).json({ error: 'Receiver not found' });
        }

        if (sender._id.equals(receiver._id)) {
            logger.error('Cannot send friend request to yourself');
            return res.status(400).json({ error: 'Cannot send friend request to yourself' });
        }

        // case where the user is already friend with the receiver
        if (sender.friends.some(f => f.equals(receiver._id))) {
            logger.error('Already friends');
            return res.status(400).json({ error: 'Already friends' });
        }

        const existingRequest = await FriendRequest.findOne({
            sender: sender._id,
            receiver: receiver._id,
            status: 'pending',
        });
        if (existingRequest) {
            logger.error('Friend request already exists');
            return res.status(400).json({ error: 'Friend request already exists' });
        }

        const existingReverseRequest = await FriendRequest.findOne({
            sender: receiver._id,
            receiver: sender._id,
            status: 'pending',
        });
        if (existingReverseRequest) {
            if (sender && receiver) {
                sender.friends.push(receiver._id);
                receiver.friends.push(sender._id);

                await sender.save();
                await receiver.save();
            }
            await existingReverseRequest.deleteOne();
            return res.json({ message: 'Friend request accepted', friend: receiver });
        }

        const friendRequestData = {
            sender: sender._id,
            receiver: receiver._id,
            status: 'pending',
        };

        const friendsRequest = new FriendRequest(friendRequestData);
        await friendsRequest.save();
        return res.json({ message: 'Friend request sent', friend: receiver });
    } catch (err: unknown) {
        logger.error('Could not send friend request : ' + err);
        return res.status(500).json({ error: 'An error has occured' });
    }
};

const acceptFriendRequest = async (req: Request, res: Response) => {
    try {
        const { requestId } = req.body;

        if (!requestId) {
            return res.status(400).json({ error: 'No requestId provided' });
        }

        const friendRequest = await FriendRequest.findById(requestId);
        if (friendRequest === null) {
            return res.status(404).json({ error: 'Friend request not found' });
        }

        // Add each user to the other's friends list
        const sender = await User.findById(friendRequest.sender);
        const receiver = await User.findById(friendRequest.receiver);

        if (sender && receiver) {
            sender.friends.push(receiver._id);
            receiver.friends.push(sender._id);

            await sender.save();
            await receiver.save();
        }

        // Temp delete the friend request for now (TODO : use status field)
        await friendRequest.deleteOne();

        return res.json({ message: `Friend request accepted ` });
    } catch (err: unknown) {
        logger.error('Could not handle friend request : ' + err);
        return res.status(500).json({ error: 'An error has occurred' });
    }
};

const declineFriendRequest = async (req: Request, res: Response) => {
    try {
        const { requestId } = req.body;

        if (!requestId) {
            return res.status(400).json({ error: 'No requestId provided' });
        }

        const friendRequest = await FriendRequest.findById(requestId);
        if (friendRequest === null) {
            return res.status(404).json({ error: 'Friend request not found' });
        }

        // TODO géré cas refus : notifier l'user qui a fait la demande d'ami

        // Temp delete the friend request for now (TODO : use status field)
        await friendRequest.deleteOne();

        return res.json({ message: `Friend request declined ` });
    } catch (err: unknown) {
        logger.error('Could not handle friend request : ' + err);
        return res.status(500).json({ error: 'An error has occurred' });
    }
};

const sendBugReport = async (req: Request, res: Response) => {
    try {
        const { description, app_version, platform } = req.body;
        const screenshot_url = req.file ? 'uploads/bugReport/' + req.file.filename : '';
        const bugReport = new BugReport({
            description,
            screenshot_url: screenshot_url,
            app_version,
            platform,
            user: req.user.id,
            status: 'open', // Par défaut, le bug est ouvert
        });

        await bugReport.save();
        res.status(201).json({ message: 'Bug report created successfully', bugReport });
    } catch (error) {
        logger.error('Error creating bug report : ' + error);
        res.status(400).json({ message: 'An error has occured' });
    }
};

export { getUserInformation, updateUsername, updatePassword, updateStatus, updateProfilePicture, getUserFriends, searchUsers, removeFriend, getFriendRequests, sendFriendRequest, acceptFriendRequest, declineFriendRequest, sendBugReport };
