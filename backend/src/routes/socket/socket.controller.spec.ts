import { Request, Response } from 'express';
import * as socketController from './socket.controller.js';
import * as socketService from './socket.service.js';

// Mock plus sophistiqué pour Message
jest.mock('../../models/message.js');
jest.mock('../../models/room.js');
jest.mock('../../models/user.js');
jest.mock('./socket.service.js');

import Room from '../../models/room.js';
import User from '../../models/user.js';
import Message from '../../models/message.js';
import { Types } from 'mongoose';
import logger from '../../utils/logger.js';

describe('Socket Controller', () => {
    let mockRequest: Partial<Request>;
    let mockResponse: Partial<Response>;

    beforeEach(() => {
        mockRequest = {};
        mockResponse = {
            status: jest.fn().mockReturnThis(),
            json: jest.fn(),
        };
    });

    beforeAll(() => {
        logger.info = jest.fn(); // pour mute les logs
        logger.error = jest.fn(); // pour mute les logs
    });

    afterEach(() => {
        jest.clearAllMocks();
    });

    describe('sendMessage', () => {
        it('should send a message successfully', async () => {
            const mockRoom = { _id: 'room123', name: 'testroom' };
            const mockMessage = {
                _id: 'message123',
                content: 'test message',
                createdAt: new Date(),
                user: { username: 'testuser' },
                room: mockRoom,
            };
            const mockUser = {
                _id: 'user123',
                username: 'testuser',
            };
            (User.findById as jest.Mock).mockReturnValue({
                select: jest.fn().mockResolvedValue({ username: 'testuser', _id: 'user123' }),
            });

            (Room.findOne as jest.Mock).mockResolvedValue(mockRoom);
            (Message as unknown as jest.Mock).mockImplementationOnce(() => ({
                _id: 'message123',
                content: 'test message',
                user: mockUser,
                room: mockRoom,
                createdAt: mockMessage.createdAt,
                save: jest.fn(),

            }));

            mockRequest.body = { roomName: mockRoom.name, content: 'test message' };
            mockRequest.user = { id: mockUser._id };
            await socketController.sendMessage(mockRequest as Request, mockResponse as Response);
            expect(socketService.sendMessageToRoom).toHaveBeenCalledWith(mockUser._id, mockRoom.name, {
                content: 'test message',
                createdAt: mockMessage.createdAt,
                username: 'testuser',
                id: 'message123',
            });
            expect(mockResponse.status).toHaveBeenCalledWith(201);
            expect(mockResponse.json).toHaveBeenCalledWith({
                message: {
                    content: 'test message',
                    createdAt: mockMessage.createdAt,
                    username: 'testuser',
                    id: 'message123',
                },
            });
        });

        it('should return 400 if message content is missing', async () => {
            mockRequest.body = { roomName: 'testroom' };
            mockRequest.user = { id: 'user123' };
            await socketController.sendMessage(mockRequest as Request, mockResponse as Response);
            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Message content is required' });
        });

        it('should return 400 if room name is missing', async () => {
            mockRequest.body = { content: 'test message' };
            mockRequest.user = { id: 'user123' };
            await socketController.sendMessage(mockRequest as Request, mockResponse as Response);
            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Message content is required' });
        });

        it('should return 404 if user is not found', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                select: jest.fn().mockResolvedValue(null),
            });

            mockRequest.body = { roomName: 'testroom', content: 'test message' };
            mockRequest.user = { id: 'user123' };

            await socketController.sendMessage(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'User not found' });
        });

        it('should return 404 if room is not found', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                select: jest.fn().mockResolvedValue({ username: 'testuser', _id: 'user123' }),
            });
            (Room.findOne as jest.Mock).mockResolvedValue(null);

            mockRequest.body = { roomName: 'testroom', content: 'test message' };
            mockRequest.user = { id: 'user123' };

            await socketController.sendMessage(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Room not found' });
        });

        it('should handle errors and return 500', async () => {
            (User.findById as jest.Mock).mockReturnValue({
                select: jest.fn().mockRejectedValue(new Error('Test error')),
            });
            mockRequest.body = { roomName: 'testroom', content: 'test message' };
            mockRequest.user = { id: 'user123' };

            await socketController.sendMessage(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    error: 'Internal server error',
                }),
            );
        });
    });

    describe('getMessages', () => {
        it('should get messages successfully', async () => {
            const mockRoom = { _id: 'room123', name: 'testroom' };
            const mockMessages = [{ content: 'test message' }];

            (Room.findOne as jest.Mock).mockResolvedValue(mockRoom);
            (socketService.getMessagesByRoomId as jest.Mock).mockResolvedValue(mockMessages);

            mockRequest.query = { roomName: 'testroom' };

            await socketController.getMessages(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.json).toHaveBeenCalledWith({ messages: mockMessages });
        });

        it('should return 400 if room name is missing', async () => {
            mockRequest.query = {};
            await socketController.getMessages(mockRequest as Request, mockResponse as Response);
            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Room name is required' });
        });

        it('should return 404 if room is not found', async () => {
            (Room.findOne as jest.Mock).mockResolvedValue(null);
            mockRequest.query = { roomName: 'testroom' };

            await socketController.getMessages(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should handle errors and return 500', async () => {
            (Room.findOne as jest.Mock).mockRejectedValue(new Error('Test error'));
            mockRequest.query = { roomName: 'testroom' };

            await socketController.getMessages(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Internal server error' });
        });
    });

    describe('deleteMessageFromRoom', () => {
        it('should delete a message successfully', async () => {
            const mockUser = { _id: 'user123' };
            const mockRoom = { _id: 'room123', name: 'testroom' };

            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (Room.findOne as jest.Mock).mockResolvedValue(mockRoom);
            (socketService.deleteMessageFromRoom as jest.Mock).mockImplementation(() => {});

            mockRequest.query = { roomName: 'testroom', messageId: new Types.ObjectId().toString() };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Message deleted' });
            expect(socketService.deleteMessageFromRoom).toHaveBeenCalledWith('user123', 'testroom', mockRequest.query.messageId);
        });

        it('should return 400 if room name is missing', async () => {
            mockRequest.query = { messageId: 'message123' };
            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);
            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Room name and message ID are required' });
        });
        it('should return 400 if messageId is missing', async () => {
            mockRequest.query = { roomName: 'testroom' };
            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);
            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Room name and message ID are required' });
        });

        it('should return 400 if messageId is invalid', async () => {
            mockRequest.query = { roomName: 'testroom', messageId: 'invalid-id' };
            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(400);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Invalid message ID' });
        });

        it('should return 404 if user is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.query = { roomName: 'testroom', messageId: new Types.ObjectId().toString() };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should return 404 if room is not found', async () => {
            (User.findById as jest.Mock).mockResolvedValue({});
            (Room.findOne as jest.Mock).mockResolvedValue(null);

            mockRequest.query = { roomName: 'testroom', messageId: new Types.ObjectId().toString() };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Room not found' });
        });
        it('should handle errors and return 500', async () => {
            (User.findById as jest.Mock).mockRejectedValue(new Error('Test error'));
            mockRequest.query = { roomName: 'testroom', messageId: new Types.ObjectId().toString() };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteMessageFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'Internal server error' });
        });
    });

    describe('deleteAllMessagesFromRoom', () => {
        it('should delete all messages successfully', async () => {
            const mockUser = { _id: 'user123' };
            const mockRoom = { _id: 'room123', name: 'testroom' };

            (Room.findOne as jest.Mock).mockResolvedValue(mockRoom);
            (User.findById as jest.Mock).mockResolvedValue(mockUser);
            (socketService.deleteAllMessagesFromRoom as jest.Mock).mockImplementation(() => {});

            mockRequest.query = { roomName: 'testroom' };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteAllMessagesFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.json).toHaveBeenCalledWith({ message: 'Messages deleted' });
            expect(socketService.deleteAllMessagesFromRoom).toHaveBeenCalledWith('user123', 'room123', 'testroom');
        });

        it('should return 404 if room is not found', async () => {
            (Room.findOne as jest.Mock).mockResolvedValue(null);
            mockRequest.query = { roomName: 'testroom' };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteAllMessagesFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should return 404 if user is not found', async () => {
            (Room.findOne as jest.Mock).mockResolvedValue({});
            (User.findById as jest.Mock).mockResolvedValue(null);
            mockRequest.query = { roomName: 'testroom' };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteAllMessagesFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(404);
            expect(mockResponse.json).toHaveBeenCalledWith({ error: 'An error has occured' });
        });

        it('should handle errors and return 500', async () => {
            (User.findById as jest.Mock).mockRejectedValue(new Error('Test error'));
            mockRequest.query = { roomName: 'testroom' };
            mockRequest.user = { id: 'user123' };

            await socketController.deleteAllMessagesFromRoom(mockRequest as Request, mockResponse as Response);

            expect(mockResponse.status).toHaveBeenCalledWith(500);
            expect(mockResponse.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    error: 'Internal server error',
                }),
            );
        });
    });
});
