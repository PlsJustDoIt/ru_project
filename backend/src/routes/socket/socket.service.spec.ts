import { MongoMemoryServer } from 'mongodb-memory-server';
import { io, Socket } from 'socket.io-client';
import { createServer, Server as HTTPServer } from 'http';
import { Server } from 'socket.io';
import { IUser, generateUser, createUser } from '../../models/user.js';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { socketHandler } from '../../utils/socket.js';
import * as socketApplicationService from './socket.service.js';

jest.mock('../../models/room.js');
jest.mock('../../models/message.js');

import Room from '../../models/room.js';
import Message from '../../models/message.js';
import { messageChat } from '../../interfaces/messageChat.js';
import logger from '../../utils/logger.js';
import { AddressInfo } from 'net';

let mongoServer: MongoMemoryServer;

describe('socketApplicationService', () => {
    let socket: Socket;
    let httpServer: HTTPServer;
    let ioServer: Server;
    let port: number;
    let user1: IUser;
    let user2: IUser;
    let token: string;

    beforeAll(async () => {
        mongoServer = await MongoMemoryServer.create();
        const mongoUri = mongoServer.getUri();
        await mongoose.connect(mongoUri);

        httpServer = createServer();
        ioServer = new Server(httpServer, {
            cors: {
                origin: '*',
                methods: ['GET', 'POST'],
                credentials: true,
            },
        });

        logger.info = jest.fn();
        logger.error = jest.fn();
        socketHandler.initialize(httpServer, false);
        socketApplicationService.setupSocketApplicationEvents();

        httpServer.listen(0);
        const address = httpServer.address() as AddressInfo;
        port = address.port;

        user1 = await createUser(generateUser('tata', 'toto'));
        user2 = await createUser(generateUser('toto', 'tata'));

        token = jwt.sign({ id: user1._id }, process.env.JWT_ACCESS_SECRET as string, { expiresIn: '1h' });
    });

    beforeEach((done) => {
        socket = io(`http://localhost:${port}`, {
            auth: {
                token: token,
            },
            ackTimeout: 1000,
            reconnectionDelay: 0,
            timeout: 1000, // Shorter timeout
        });
        socket.on('connect', () => {
            done();
        });
    });

    afterEach(() => {
        if (socket.connected) {
            socket.disconnect();
        }
        jest.resetAllMocks();
    });

    afterAll(async () => {
        ioServer.close();
        httpServer.close();
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('server socket should handle join_global_room event', (done) => {
        socket.on('room_joined', (data) => {
            expect(data.roomName).toBe('Global');
            done();
        });

        (Room.findOne as jest.Mock).mockResolvedValue({ name: 'Global' });

        socket.emit('join_global_room');
    });

    it('should throw an error if the global room doesnt exist', (done) => {
        socket.on('error', (error) => {
            expect(error).toBe('Failed to join global room');
            done();
        });

        (Room.findOne as jest.Mock).mockResolvedValue(null);

        socket.emit('join_global_room');
    });

    it('server socket should handle join_room event when the room exists', (done) => {
        const mockRoom = { name: [user1._id, user2._id].sort().join('_') };
        socket.on('room_joined', (data) => {
            expect(data.roomName).toBeDefined();
            expect(data.roomName).toBe(mockRoom.name);
            done();
        });

        (Room.findOne as jest.Mock).mockResolvedValue(mockRoom);

        socket.emit('join_room', [user1._id, user2._id]);
    });

    it('server socket should handle join_room event when the room doesnt exists', (done) => {
        const mockRoom = { name: [user1._id, user2._id].sort().join('_') };
        socket.on('room_joined', (data) => {
            expect(data.roomName).toBeDefined();
            expect(data.roomName).toBe(mockRoom.name);
            done();
        });

        (Room.findOne as jest.Mock).mockResolvedValue(null);
        (Room.create as jest.Mock).mockResolvedValue(mockRoom);
        socket.emit('join_room', [user1._id, user2._id]);
    });

    it('server socket should handle leave_room event', (done) => {
        const mockRoom = { name: [user1._id, user2._id].sort().join('_') };
        (Room.findOne as jest.Mock).mockResolvedValue(mockRoom);
        socket.emit('join_room', [user1._id, user2._id]);

        socket.on('room_joined', (data) => {
            expect(data.roomName).toBeDefined();
            expect(data.roomName).toBe(mockRoom.name);
        });
        socket.on('room_left', (data) => {
            expect(data.roomName).toBeDefined();
            expect(data.roomName).toBe(mockRoom.name);
            done();
        });
        socket.emit('leave_room', mockRoom.name);
    });

    it('should throw an error if the data is not provided', (done) => {
        socket.on('error', (error) => {
            expect(error).toBe('Failed to join room');
            done();
        });
        socket.emit('join_room', []);
    });
    it('should throw an error if the data length is not 2', (done) => {
        socket.on('error', (error) => {
            expect(error).toBe('Failed to join room');
            done();
        });
        socket.emit('join_room', [user1._id]);
    });

    it('should throw an error if the room is null', (done) => {
        socket.on('error', (error) => {
            expect(error).toBe('Failed to join room');
            done();
        });

        (Room.findOne as jest.Mock).mockResolvedValue(null);
        (Room.create as jest.Mock).mockResolvedValue(null);
        socket.emit('join_room', [user1._id, user2._id]);
    });

    it('should send a message to a room', async () => {
        const mockRoom = { name: 'testRoom' };
        (Room.create as jest.Mock).mockResolvedValue(mockRoom);
        const message: messageChat = { content: 'test message', createdAt: new Date(), username: user1.username, id: '123' };
        const sendMessageSpy = jest.spyOn(socketHandler, 'emitToRoom');

        await socketApplicationService.sendMessageToRoom(user1._id.toString(), mockRoom.name, message);

        expect(sendMessageSpy).toHaveBeenCalledWith(
            expect.anything(),
            'receive_message',
            mockRoom.name,
            { message },
        );
    });

    it('should get messages by room id', async () => {
        const mockRoom = { name: 'testRoom', _id: 'some id' };
        (Room.create as jest.Mock).mockResolvedValue(mockRoom);
        const mockMessage = {
            content: 'test message',
            user: { username: user1.username },
            createdAt: new Date(),
            _id: '123',
        };

        const findMock = {
            populate: jest.fn().mockReturnThis(),
            sort: jest.fn().mockReturnThis(),
            limit: jest.fn().mockResolvedValue([mockMessage]),
        };

        (Message.find as jest.Mock).mockReturnValue(findMock);

        const messages = await socketApplicationService.getMessagesByRoomId(mockRoom._id.toString());

        expect(messages).toBeDefined();
        expect(messages.length).toBeGreaterThan(0);
    });

    it('should delete a message from a room', async () => {
        const mockRoom = { name: 'testRoom', _id: 'some id' };
        (Room.create as jest.Mock).mockResolvedValue(mockRoom);
        const mockMessage = {
            content: 'test message',
            user: { username: user1.username },
            createdAt: new Date(),
            _id: '123',
        };
        (Message.find as jest.Mock).mockResolvedValue([mockMessage]);
        const deleteMessageSpy = jest.spyOn(socketHandler, 'emitToRoom');

        await socketApplicationService.deleteMessageFromRoom(user1._id.toString(), mockRoom.name, mockMessage._id.toString());

        expect(deleteMessageSpy).toHaveBeenCalledWith(
            expect.anything(),
            'receive_delete_message',
            mockRoom.name,
            { messageId: mockMessage._id.toString() },
        );
    });

    it('should delete all messages from a room', async () => {
        const mockRoom = { name: 'testRoom', _id: 'some id' };
        (Room.create as jest.Mock).mockResolvedValue(mockRoom);
        const mockMessage = {
            content: 'test message',
            user: { username: user1.username },
            createdAt: new Date(),
            _id: '123',
        };
        (Message.find as jest.Mock).mockResolvedValue([mockMessage]);
        const deleteAllMessagesSpy = jest.spyOn(socketHandler, 'emitToRoom');

        await socketApplicationService.deleteAllMessagesFromRoom(user1._id.toString(), mockRoom._id, mockRoom.name);

        expect(deleteAllMessagesSpy).toHaveBeenCalledWith(
            expect.anything(),
            'receive_delete_all_messages',
            mockRoom.name,
            {},
        );
    });
});

// it('should handle join_global_room event', (done) => {
//         socket.emit('join_global_room');
//         socket.on('room_joined', (data) => {
//             expect(data.roomName).toBe('Global');
//             done();
//         });
//     });

//     it('should handle join_room event', (done) => {
//         socket.emit('join_room', [user1._id, user2._id]);
//         socket.on('room_joined', (data) => {
//             expect(data.roomName).toBeDefined();
//             done();
//         });
//     });
