import { Request, Response } from 'express';
import * as userController from './user.controller.js';
import User from '../../models/user.js';
import FriendRequest from '../../models/friendsRequest.js';
import BugReport from '../../models/bugReport.js';
import { compare } from 'bcrypt';
import { getUserByUsername, levenshteinDistance } from './user.service.js';
import { Types } from 'mongoose';
import logger from '../../utils/logger.js';

jest.mock('../../models/user');
jest.mock('../../models/friendsRequest');
jest.mock('../../models/bugReport');
jest.mock('bcrypt');
jest.mock('./user.service');

describe('User Controller tests', () => {
    let mockRequest: Partial<Request>;
    let mockResponse: Partial<Response>;

    beforeAll(() => {
        logger.info = jest.fn();
        logger.error = jest.fn();
    });

    beforeEach(() => {
        mockRequest = {};
        mockResponse = {
            status: jest.fn().mockReturnThis(),
            json: jest.fn(),
        };
    });

    afterEach(() => {
        jest.clearAllMocks();
    });

    describe('getUserInformation', () => {
        let mockUser: { _id: string; username: string; friends: never[]; status: string };
        beforeEach(() => {
            mockUser = {
                _id: '1',
                username: 'testUser',
                friends: [],
                status: 'en ligne',
            };
        });
        it('should return user information on successful retrieval', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                populate: jest.fn().mockResolvedValue(mockUser),
            });
            mockRequest.user = { id: '1' };

            await userController.getUserInformation(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(mockResponse.json).toHaveBeenCalledWith({ user: mockUser });
        });

        it('should return 500 error if user retrieval fails', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                populate: jest.fn().mockRejectedValue(new Error('Database error')),
            });
            mockRequest.user = { id: '1' };

            await userController.getUserInformation(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });
    });

    describe('updateUsername', () => {
        it('should update username successfully', async () => {
            const mockUser = { _id: '1', username: 'oldUser', save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (getUserByUsername as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'newUser' };

            await userController.updateUsername(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(getUserByUsername).toHaveBeenCalledWith('newUser');
            expect(mockUser.save).toHaveBeenCalled();
            expect(mockResponse.json).toHaveBeenCalledWith({ username: 'newUser' });
        });

        it('should return 400 error if username already exists', async () => {
            (getUserByUsername as jest.Mock).mockResolvedValue({});
            mockRequest.body = { username: 'existingUser' };

            await userController.updateUsername(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'A user with this username already exists' });
        });

        it('should return 400 error if username is invalid', async () => {
            mockRequest.body = { username: 'in' };

            await userController.updateUsername(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
        });

        it('should return 500 error if user is not found', async () => {
            (getUserByUsername as jest.Mock).mockResolvedValue(null);
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'newUser' };

            await userController.updateUsername(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should return 400 error if username is missing', async () => {
            mockRequest.body = {};

            await userController.updateUsername(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Username dosn\'t exists' });
        });
    });

    describe('updatePassword', () => {
        it('should update password successfully', async () => {
            const mockUser = { _id: '1', password: 'oldPassword', save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (compare as jest.Mock).mockResolvedValue(true);
            mockRequest.user = { id: '1' };
            mockRequest.body = { oldPassword: 'oldPassword', password: 'newPassword' };

            await userController.updatePassword(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(compare).toHaveBeenCalledWith('oldPassword', 'oldPassword');
            expect(mockUser.save).toHaveBeenCalled();
            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Password updated' });
        });

        it('should return 400 error if old password is incorrect', async () => {
            const mockUser = { _id: '1', password: 'oldPassword', save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (compare as jest.Mock).mockResolvedValue(false);
            mockRequest.user = { id: '1' };
            mockRequest.body = { oldPassword: 'wrongPassword', password: 'newPassword' };

            await userController.updatePassword(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: { message: 'Incorrect old password', field: 'oldPassword' } });
        });

        it('should return 400 error if password is invalid', async () => {
            mockRequest.body = { oldPassword: 'old', password: 'in' };

            await userController.updatePassword(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
        });

        it('should return 500 error if user is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { oldPassword: 'oldPassword', password: 'newPassword' };

            await userController.updatePassword(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should return 400 error if old password is missing', async () => {
            mockRequest.body = { password: 'newPassword' };

            await userController.updatePassword(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: { message: 'Old password dosn\'t exists', field: 'oldPassword' } });
        });

        it('should return 400 error if password is missing', async () => {
            mockRequest.body = { oldPassword: 'oldPassword' };

            await userController.updatePassword(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: { message: 'Password dosn\'t exists', field: 'password' } });
        });
    });

    describe('updateStatus', () => {
        it('should update status successfully', async () => {
            const mockUser = { _id: '1', status: 'oldStatus', save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            mockRequest.user = { id: '1' };
            mockRequest.body = { status: 'newStatus' };

            await userController.updateStatus(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(mockUser.status).toBe('newStatus');
            expect(mockUser.save).toHaveBeenCalled();
            expect(mockResponse.json).toHaveBeenCalledWith({ status: 'newStatus' });
        });

        it('should return 400 error if status is missing', async () => {
            mockRequest.body = {};

            await userController.updateStatus(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Status dosn\'t exists' });
        });

        it('should return 404 error if user is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { status: 'newStatus' };

            await userController.updateStatus(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });
    });

    describe('updateProfilePicture', () => {
        it('should update profile picture successfully', async () => {
            const mockUser = { _id: '1', avatarUrl: 'oldUrl', save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            mockRequest.user = { id: '1' };
            mockRequest.file = { filename: 'newFile' } as Express.Multer.File;

            await userController.updateProfilePicture(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(mockUser.avatarUrl).toBe('uploads/avatar/newFile');
            expect(mockUser.save).toHaveBeenCalled();
            expect(mockResponse.json).toHaveBeenCalledWith({ avatarUrl: 'uploads/avatar/newFile' });
        });

        it('should return 400 error if no file is uploaded', async () => {
            mockRequest.file = undefined;
            mockRequest.user = { id: '1' };
            await userController.updateProfilePicture(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'No file uploaded' });
        });

        it('should return 404 error if user is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.file = { filename: 'newFile' } as Express.Multer.File;

            await userController.updateProfilePicture(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });
    });

    describe('getUserFriends', () => {
        it('should return user friends successfully', async () => {
            const mockUser = { _id: '1', friends: [{ username: 'friend1', status: 'online', avatarUrl: 'url1', _id: '2' }] };
            (User.findById as jest.Mock).mockReturnValue({
                populate: jest.fn().mockResolvedValue(mockUser),
            });
            mockRequest.user = { id: '1' };

            await userController.getUserFriends(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(mockResponse.json).toHaveBeenCalledWith({
                friends: [{
                    username: 'friend1',
                    status: 'online',
                    avatarUrl: 'url1',
                    _id: '2',
                }],
            });
        });

        it('should return 404 error if user is not found', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                populate: jest.fn().mockResolvedValue(null),
            });
            mockRequest.user = { id: '1' };

            await userController.getUserFriends(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });

        it('should return 500 error if user retrieval fails', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                populate: jest.fn().mockRejectedValue(new Error('Database error')),
            });
            mockRequest.user = { id: '1' };

            await userController.getUserFriends(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });
    });

    describe('searchUsers', () => {
        it('should return search results successfully', async () => {
            const mockUsers = [{ username: 'testUser', avatarUrl: 'url', status: 'online', _id: '2' }];
            (User.find as jest.Mock).mockResolvedValue(mockUsers);
            (FriendRequest.find as jest.Mock).mockResolvedValue([]);
            mockRequest.user = { id: '1' };
            mockRequest.query = { query: 'test' };
            (levenshteinDistance as jest.Mock).mockReturnValue(0);

            await userController.searchUsers(mockRequest as Request, mockResponse as Response);

            expect(User.find).toHaveBeenCalledWith({ username: new RegExp('test', 'i') });
            expect(mockResponse.json).toHaveBeenCalled();
        });

        it('should return 400 error if no query is provided', async () => {
            mockRequest.query = {};

            await userController.searchUsers(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'No query provided' });
        });

        it('should return 400 error if query is too short', async () => {
            mockRequest.query = { query: 'te' };

            await userController.searchUsers(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Search username must be at least 3 characters' });
        });

        it('should return 404 error if no users are found', async () => {
            (User.find as jest.Mock).mockReturnValue({
                select: jest.fn().mockReturnValue({
                    limit: jest.fn().mockResolvedValue([]),
                }),
            });

            mockRequest.user = { id: '1' };
            mockRequest.query = { query: 'test' };

            await userController.searchUsers(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'No users found' });
        });
    });

    describe('removeFriend', () => {
        it('should remove friend successfully', async () => {
            const mockUser = { _id: '1', friends: [{ toString: () => '2' }], save: jest.fn() };
            const mockFriend = { _id: '2', friends: [{ toString: () => '1' }], save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValueOnce(mockUser).mockResolvedValueOnce(mockFriend);
            mockRequest.user = { id: '1' };
            mockRequest.body = { friendId: '2' };

            await userController.removeFriend(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(User.findById).toHaveBeenCalledWith('2');
            expect(mockUser.save).toHaveBeenCalled();
            expect(mockFriend.save).toHaveBeenCalled();
            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Friend removed successfully', user: mockUser });
        });

        it('should return 400 error if no friendId is provided', async () => {
            mockRequest.body = {};

            await userController.removeFriend(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'No friendId provided' });
        });

        it('should return 404 error if user is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { friendId: '2' };

            await userController.removeFriend(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });

        it('should return 404 error if friend is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValueOnce({});
            (User.findById as jest.Mock).mockResolvedValueOnce(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { friendId: '2' };

            await userController.removeFriend(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Friend not found' });
        });
    });

    describe('getFriendRequests', () => {
        it('should return friend requests successfully', async () => {
            const mockUser = { _id: '1' };
            const mockFriendRequests = [{ _id: '123', sender: { username: 'sender', avatarUrl: 'url', _id: '3' }, createdAt: 'date', status: 'pending' }];
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (FriendRequest.find as jest.Mock).mockResolvedValue(mockFriendRequests);
            mockRequest.user = { id: '1' };

            await userController.getFriendRequests(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith('1');
            expect(FriendRequest.find).toHaveBeenCalledWith({ receiver: mockUser._id });
            expect(mockResponse.json).toHaveBeenCalled();
        });

        it('should return 404 error if user is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };

            await userController.getFriendRequests(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });
    });

    describe('sendFriendRequest', () => {
        it('should send friend request successfully', async () => {
            const mockSender = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            const mockReceiver = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockSender);
            (User.findOne as jest.Mock).mockResolvedValue(mockReceiver);
            (FriendRequest.findOne as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: mockSender._id };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(User.findById).toHaveBeenCalledWith(mockSender._id);
            expect(User.findOne).toHaveBeenCalledWith({ username: 'receiver' });
            expect(FriendRequest.findOne).toHaveBeenCalled();
            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Friend request sent', friend: mockReceiver });
        });

        it('should return 404 error if sender is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });

        it('should return 404 error if receiver is not found', async () => {
            const mockSender = { _id: '1', friends: [], save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockSender);
            (User.findOne as jest.Mock).mockResolvedValue(null);
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Receiver not found' });
        });

        it('should return 400 error if trying to send friend request to yourself', async () => {
            const mockUser = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (User.findOne as jest.Mock).mockResolvedValue(mockUser);
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Cannot send friend request to yourself' });
        });

        it('should return 400 error if already friends', async () => {
            const mockSender = { _id: new Types.ObjectId(), friends: [{ equals: () => true }], save: jest.fn() };
            const mockReceiver = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockSender);
            (User.findOne as jest.Mock).mockResolvedValue(mockReceiver);
            mockRequest.user = { id: mockSender._id };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Already friends' });
        });

        it('should return 400 error if friend request already exists', async () => {
            const mockSender = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            const mockReceiver = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockSender);
            (User.findOne as jest.Mock).mockResolvedValue(mockReceiver);
            (FriendRequest.findOne as jest.Mock).mockResolvedValue({});
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Friend request already exists' });
        });

        it('should accept friend request if reverse request exists', async () => {
            const mockSender = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            const mockReceiver = { _id: new Types.ObjectId(), friends: [], save: jest.fn() };
            const mockFriendRequest = { sender: mockReceiver._id, receiver: mockSender._id, status: 'pending', deleteOne: jest.fn() };
            (User.findById as jest.Mock).mockResolvedValue(mockSender);
            (User.findOne as jest.Mock).mockResolvedValue(mockReceiver);
            (FriendRequest.findOne as jest.Mock).mockResolvedValueOnce(null).mockResolvedValueOnce(mockFriendRequest);
            mockRequest.user = { id: '1' };
            mockRequest.body = { username: 'receiver' };

            await userController.sendFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Friend request accepted', friend: mockReceiver });
        });
    });

    describe('acceptFriendRequest', () => {
        it('should accept friend request successfully', async () => {
            const mockSender = { _id: '1', friends: [], save: jest.fn() };
            const mockReceiver = { _id: '2', friends: [], save: jest.fn() };
            const mockFriendRequest = { sender: mockSender._id, receiver: mockReceiver._id, deleteOne: jest.fn() };
            (FriendRequest.findById as jest.Mock).mockResolvedValue(mockFriendRequest);
            (User.findById as jest.Mock).mockResolvedValueOnce(mockSender).mockResolvedValueOnce(mockReceiver);
            mockRequest.body = { requestId: '123' };

            await userController.acceptFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(FriendRequest.findById).toHaveBeenCalledWith('123');
            expect(mockResponse.json).toHaveBeenCalledWith({ message: `Friend request accepted ` });
        });

        it('should return 400 error if no requestId is provided', async () => {
            mockRequest.body = {};

            await userController.acceptFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'No requestId provided' });
        });

        it('should return 404 error if friend request is not found', async () => {
            (FriendRequest.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.body = { requestId: '123' };

            await userController.acceptFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Friend request not found' });
        });
    });

    describe('declineFriendRequest', () => {
        it('should decline friend request successfully', async () => {
            const mockFriendRequest = { sender: '1', receiver: '2', deleteOne: jest.fn() };
            (FriendRequest.findById as jest.Mock).mockResolvedValue(mockFriendRequest);
            mockRequest.body = { requestId: '123' };

            await userController.declineFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(FriendRequest.findById).toHaveBeenCalledWith('123');
            expect(mockResponse.json).toHaveBeenCalledWith({ message: `Friend request declined ` });
        });

        it('should return 400 error if no requestId is provided', async () => {
            mockRequest.body = {};

            await userController.declineFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'No requestId provided' });
        });

        it('should return 404 error if friend request is not found', async () => {
            (FriendRequest.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.body = { requestId: '123' };

            await userController.declineFriendRequest(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Friend request not found' });
        });
    });

    describe('sendBugReport', () => {
        it('should send bug report successfully', async () => {
            const mockBugReport = { save: jest.fn() };
            (BugReport as unknown as jest.Mock).mockReturnValue(mockBugReport);
            mockRequest.user = { id: '1' };
            mockRequest.body = { description: 'desc', app_version: '1.0', platform: 'ios' };
            mockRequest.file = { filename: 'file' } as Express.Multer.File;

            await userController.sendBugReport(mockRequest as Request, mockResponse as Response);

            expect(mockBugReport.save).toHaveBeenCalled();
            expect(mockResponse.status).toHaveBeenCalledWith(201);
            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Bug report created successfully', bugReport: mockBugReport });
        });

        it('should send bug report successfully without a screenshot', async () => {
            const mockBugReport = { save: jest.fn() };
            (BugReport as unknown as jest.Mock).mockReturnValue(mockBugReport);
            mockRequest.user = { id: '1' };
            mockRequest.body = { description: 'desc', app_version: '1.0', platform: 'ios' };
            mockRequest.file = undefined;

            await userController.sendBugReport(mockRequest as Request, mockResponse as Response);

            expect(mockBugReport.save).toHaveBeenCalled();
            expect(mockResponse.status).toHaveBeenCalledWith(201);
            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Bug report created successfully', bugReport: mockBugReport });
        });
    });
});
