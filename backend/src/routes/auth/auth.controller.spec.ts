jest.mock('jsonwebtoken');
jest.mock('../../models/refreshToken.js');
jest.mock('../../models/user.js');
jest.mock('./auth.service.js');
jest.mock('fs/promises', () => ({
    unlink: jest.fn(), // On mocke `unlink` mais sans comportement défini
}));

import { deleteUser, loginUser, logoutUser, refreshUserToken, registerUser } from './auth.controller.js';
import * as authService from './auth.service.js'; // Importer pour mocker
import { Request, Response } from 'express';
import * as jwt from 'jsonwebtoken';
import RefreshToken from '../../models/refreshToken.js';
import User from '../../models/user.js';
import * as fsPromises from 'fs/promises';
import refreshToken from '../../models/refreshToken.js';
import logger from '../../utils/logger.js';

// Common test state
type TestContext = {
    req: Partial<Request>;
    res: Partial<Response>;
    statusMock: jest.Mock;
    jsonMock: jest.Mock;
};

// Setup common test environment
function setupTest(): TestContext {
    const jsonMock = jest.fn();
    const statusMock = jest.fn().mockReturnValue({ json: jsonMock });

    return {
        req: {
            body: {},
            headers: {},
            user: {},
        },
        res: {
            status: statusMock,
            json: jsonMock,
        },
        statusMock,
        jsonMock,
    };
}

beforeAll(async () => {
    logger.info = jest.fn(); // pour mute les logs
    logger.error = jest.fn(); // pour mute les logs
    jest.spyOn(authService, 'generateAccessToken').mockReturnValue('newAccessToken');
});

describe('auth controller tests', () => {
    // let req: Partial<Request>;
    // let res: Partial<Response>;
    // let statusMock: jest.Mock;
    // let jsonMock: jest.Mock;
    let testContext: TestContext;

    describe('registerUser tests', () => {
        beforeEach(() => {
            testContext = setupTest();
            (User.findOne as jest.Mock).mockReset();
            jest.spyOn(authService, 'validateCredentials').mockReset();
            jest.spyOn(authService, 'generateTokens').mockReset();
        });

        it('should register the user with a 200 status code', async () => {
            const { req, res, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'password123';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: true });

            (User.findOne as jest.Mock).mockResolvedValue(null);
            jest.spyOn(authService, 'generateTokens').mockResolvedValue({
                accessToken: 'testAccessToken',
                refreshToken: 'testRefreshToken',
            });

            await registerUser(req as Request, res as Response);

            expect(jsonMock).toHaveBeenCalledWith({ accessToken: 'testAccessToken', refreshToken: 'testRefreshToken' });
        });

        it('should return 400 if creds are invalid', async () => {
            const { req, res, statusMock, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'test';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: false, error: 'Invalid credentials' });
            await registerUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(400);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Invalid credentials' });
        });

        it('should return 400 if user already exists', async () => {
            const { req, res, statusMock, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'test';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: true });
            (User.findOne as jest.Mock).mockResolvedValue({ username: 'testuser' });
            await registerUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(400);
            expect(jsonMock).toHaveBeenCalledWith({ error: { message: 'User already exists', field: 'username' } });
        });

        it('should return 500 if an error occurs', async () => {
            const { req, res, statusMock, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'test';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: true });
            (User.findOne as jest.Mock).mockRejectedValue(new Error('Database error'));
            await registerUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(500);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'An error has occurred' });
        });
    });

    describe('loginUser tests', () => {
        let testContext: TestContext;
        beforeEach(() => {
            testContext = setupTest();
            (User.findOne as jest.Mock).mockReset();
            (authService.authenticate as jest.Mock).mockReset();
            jest.spyOn(authService, 'validateCredentials').mockReset();
            jest.spyOn(authService, 'generateTokens').mockReset();
        });

        it('should login the user with a 200 status code', async () => {
            const { req, res, jsonMock } = testContext;
            const mockUser = {
                username: 'testuser',
                password: 'password123',
                _id: 'userId',
            };
            req.body.username = 'testuser';
            req.body.password = 'password123';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: true });

            (User.findOne as jest.Mock).mockResolvedValue(mockUser);
            (authService.authenticate as jest.Mock).mockResolvedValue(mockUser);
            jest.spyOn(authService, 'generateTokens').mockResolvedValue({
                accessToken: 'testAccessToken',
                refreshToken: 'testRefreshToken',
            });

            await loginUser(req as Request, res as Response);

            expect(jsonMock).toHaveBeenCalledWith({ accessToken: 'testAccessToken', refreshToken: 'testRefreshToken' });
        });

        it('should return 400 if user is already connected', async () => {
            const { req, res, statusMock, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'test';
            req.headers!.authorization = 'Bearer token';

            await loginUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(400);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'User is already connected' });
        });

        it('should return 400 if creds are invalid', async () => {
            const { req, res, statusMock, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'test';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: false, error: 'Invalid credentials' });

            await loginUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(400);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Invalid credentials' });
        });

        it('should return 500 if an error occurs', async () => {
            const { req, res, statusMock, jsonMock } = testContext;
            req.body.username = 'testuser';
            req.body.password = 'test';
            jest.spyOn(authService, 'validateCredentials').mockReturnValue({ valid: true });
            (User.findOne as jest.Mock).mockRejectedValue(new Error('Database error'));

            await loginUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(500);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'An error has occurred' });
        });
    });

    describe('logoutUser tests', () => {
        let testCtx: TestContext;
        beforeEach(() => {
            testCtx = setupTest();

            // Reset specific mocks relevant to this test group
            (User.findById as jest.Mock).mockReset();
            (RefreshToken.findOneAndDelete as jest.Mock).mockReset();
        });

        it('should logout the user with a 200 status code', async () => {
            const { req, res, jsonMock } = testCtx;
            const mockUser = {
                username: 'testuser',
                password: 'password123',
                _id: 'userId',
            };
            req.user!.id = 'userId';
            req.body.refreshToken = 'testRefreshToken';
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (RefreshToken.findOneAndDelete as jest.Mock).mockResolvedValue('testRefreshToken');

            await logoutUser(req as Request, res as Response);

            expect(jsonMock).toHaveBeenCalledWith({ message: 'Logged out' });
        });

        it('should return 403 if no refresh token is provided', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            req.body.refreshToken = null;

            await logoutUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Invalid refresh token' });
        });

        it('should return 404 if user is not found', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            req.body.refreshToken = 'testRefreshToken';
            (RefreshToken.findOneAndDelete as jest.Mock).mockResolvedValue('testRefreshToken');
            (User.findById as jest.Mock).mockResolvedValue(null);
            await logoutUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(404);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'problem with the middleware' });
        });

        it('shoud return 500 if an error occurs', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            req.body.refreshToken = 'testRefreshToken';
            (RefreshToken.findOneAndDelete as jest.Mock).mockRejectedValue(new Error('Database error'));

            await logoutUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(500);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'An error has occured' });
        });
    });

    describe('deleteUser tests', () => {
        let testCtx: TestContext;
        beforeEach(() => {
            testCtx = setupTest();

            // Reset specific mocks relevant to this test group
            (User.findById as jest.Mock).mockReset();
            (fsPromises.unlink as jest.Mock).mockReset();
        });

        afterEach(() => {
            jest.resetAllMocks();
        });

        it('should delete the user with a 200 status code', async () => {
            const { req, res, jsonMock } = testCtx;
            const mockUser = {
                username: 'testuser',
                password: 'password123',
                _id: 'userId',
                avatarUrl: 'uploads/avatar/default.png',
                deleteOne: jest.fn(),
            };
            req.user!.id = 'userId';
            req.body.refreshToken = 'testRefreshToken';
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (refreshToken.findOneAndDelete as jest.Mock).mockResolvedValue('testRefreshToken');

            await deleteUser(req as Request, res as Response);

            expect(jsonMock).toHaveBeenCalledWith({ message: 'User deleted' });
        });

        it('should delete the user with a 200 status code and delete the custom avatar', async () => {
            const { req, res, jsonMock } = testCtx;
            const mockUser = {
                username: 'testuser',
                password: 'password123',
                _id: 'userId',
                avatarUrl: 'uploads/avatar/test.png',
                deleteOne: jest.fn(),
            };
            req.user!.id = 'userId';
            req.body.refreshToken = 'testRefreshToken';
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (fsPromises.unlink as jest.Mock).mockResolvedValue(undefined); // Simule une suppression réussie

            await deleteUser(req as Request, res as Response);

            expect(jsonMock).toHaveBeenCalledWith({ message: 'User deleted' });
        });

        it('should get an error if the custom avatar cannot be deleted', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            const mockUser = {
                username: 'testuser',
                password: 'password123',
                _id: 'userId',
                avatarUrl: 'uploads/avatar/test.png',
                deleteOne: jest.fn(),
            };
            req.user!.id = 'userId';
            req.body.refreshToken = 'testRefreshToken';
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (fsPromises.unlink as jest.Mock).mockRejectedValue(new Error('File not found')); // Simule une erreur de suppression

            await deleteUser(req as Request, res as Response);

            expect(statusMock).toHaveBeenCalledWith(500);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should return 403 if no refresh token is provided', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            req.body.refreshToken = null;

            await deleteUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Access not authorized' });
        });
        it('should return 404 if user is not found', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            req.body.refreshToken = 'testRefreshToken';
            (User.findById as jest.Mock).mockResolvedValue(null);
            await deleteUser(req as Request, res as Response);
            expect(statusMock).toHaveBeenCalledWith(404);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'User not found' });
        });
    });

    describe('refreshUserToken tests', () => {
        let testCtx: TestContext;
        beforeEach(() => {
            testCtx = setupTest();
            testCtx.req.body.refreshToken = 'testRefreshToken';

            // Reset specific mocks relevant to this test group
            (RefreshToken.findOne as jest.Mock).mockReset();
            (RefreshToken.findOneAndDelete as jest.Mock).mockReset();
            (jwt.verify as jest.Mock).mockReset();
            (User.findById as jest.Mock).mockReset();
            (authService.generateAccessToken as jest.Mock).mockReset();
        });

        it('should refresh access token with a 200 status code', async () => {
            const { req, res, jsonMock, statusMock } = testCtx;
            (RefreshToken.findOne as jest.Mock).mockResolvedValue({
                token: 'testRefreshToken',
                userId: 'userId',
                expires: new Date(Date.now() + 3600000), // Expires in 1 hour
            });
            (jwt.verify as jest.Mock).mockReturnValue({ id: 'userId' });
            (authService.generateAccessToken as jest.Mock).mockReturnValue('newAccessToken');
            (User.findById as jest.Mock).mockReturnValue({
                select: jest.fn().mockResolvedValue({ username: 'testUser' }),
            });

            await refreshUserToken(req as Request, res as Response);

            expect(RefreshToken.findOne).toHaveBeenCalledWith({ token: 'testRefreshToken' });
            expect(jwt.verify).toHaveBeenCalledWith('testRefreshToken', process.env.JWT_REFRESH_SECRET);
            expect(authService.generateAccessToken).toHaveBeenCalledWith('userId');
            expect(User.findById).toHaveBeenCalledWith('userId');
            expect(statusMock).not.toHaveBeenCalled();
            expect(jsonMock).toHaveBeenCalledWith({ accessToken: 'newAccessToken' });
        });

        it('should return 403 if no refresh token is provided', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            req.body.refreshToken = null;

            await refreshUserToken(req as Request, res as Response);
            expect(RefreshToken.findOne).toHaveBeenCalled();

            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Invalid refresh token' });
        });

        it('should return 403 if refresh token is invalid', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            (RefreshToken.findOne as jest.Mock).mockResolvedValue(null);

            await refreshUserToken(req as Request, res as Response);

            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Invalid refresh token' });
        });

        it('should return 403 if refresh token is expired', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            (RefreshToken.findOne as jest.Mock).mockResolvedValue({
                token: 'testRefreshToken',
                userId: 'userId',
                expires: new Date(Date.now() - 3600000), // Expired 1 hour ago
            });

            await refreshUserToken(req as Request, res as Response);

            expect(RefreshToken.findOne).toHaveBeenCalledWith({ token: 'testRefreshToken' });
            expect(RefreshToken.findOneAndDelete).toHaveBeenCalledWith({ refreshToken: 'testRefreshToken' });
            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Refresh token expired' });
        });

        it('should return 403 if refresh token does not belong to the user', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            (RefreshToken.findOne as jest.Mock).mockResolvedValue({
                token: 'testRefreshToken',
                userId: 'userId',
                expires: new Date(Date.now() + 3600000), // Expires in 1 hour
            });
            (jwt.verify as jest.Mock).mockReturnValue({ id: 'differentUserId' });

            await refreshUserToken(req as Request, res as Response);

            expect(RefreshToken.findOne).toHaveBeenCalledWith({ token: 'testRefreshToken' });
            expect(jwt.verify).toHaveBeenCalledWith('testRefreshToken', process.env.JWT_REFRESH_SECRET);
            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Refresh token does not belong to the user' });
        });

        it('should return 500 if an error occurs during token verification', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            (RefreshToken.findOne as jest.Mock).mockResolvedValue({
                token: 'testRefreshToken',
                userId: 'userId',
                expires: new Date(Date.now() + 3600000), // Expires in 1 hour
            });
            (jwt.verify as jest.Mock).mockImplementation(() => {
                throw new Error('Token verification failed');
            });

            await refreshUserToken(req as Request, res as Response);

            expect(RefreshToken.findOne).toHaveBeenCalledWith({ token: 'testRefreshToken' });
            expect(jwt.verify).toHaveBeenCalledWith('testRefreshToken', process.env.JWT_REFRESH_SECRET);
            expect(statusMock).toHaveBeenCalledWith(500);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should return 403 if the token has expired', async () => {
            const { req, res, statusMock, jsonMock } = testCtx;
            (RefreshToken.findOne as jest.Mock).mockResolvedValue({
                token: 'testRefreshToken',
                userId: 'userId',
                expires: new Date(Date.now() + 3600000), // Expires in 1 hour
            });
            (jwt.verify as jest.Mock).mockImplementation(() => {
                throw new jwt.TokenExpiredError('test', new Date());
            });

            await refreshUserToken(req as Request, res as Response);

            expect(RefreshToken.findOne).toHaveBeenCalledWith({ token: 'testRefreshToken' });
            expect(jwt.verify).toHaveBeenCalledWith('testRefreshToken', process.env.JWT_REFRESH_SECRET);
            expect(statusMock).toHaveBeenCalledWith(403);
            expect(jsonMock).toHaveBeenCalledWith({ error: 'Token expired' });
        });
    });
});
