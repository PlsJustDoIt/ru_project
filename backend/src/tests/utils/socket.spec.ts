import { MongoMemoryServer } from 'mongodb-memory-server';
import { io, Socket } from 'socket.io-client';
import { createServer, Server as HTTPServer } from 'http';
import { Server } from 'socket.io';
import { IUser, generateUser, createUser } from '../../models/user.js';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import logger from '../../utils/logger.js';
import { socketHandler } from '../../utils/socket.js';
import { AddressInfo } from 'net';

let mongoServer: MongoMemoryServer;

describe('socket service', () => {
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

        logger.info = jest.fn(); // pour mute les logs
        logger.error = jest.fn(); // pour mute les logs
        socketHandler.initialize(httpServer, false);

        httpServer.listen(0);
        const address = httpServer.address() as AddressInfo;
        port = address.port;

        user1 = await createUser(generateUser('tata', 'toto'));
        user2 = await createUser(generateUser('toto', 'tata'));
        // room = await createRoom({ name: 'testRoom' });

        token = jwt.sign({ id: user1._id }, process.env.JWT_ACCESS_SECRET as string, { expiresIn: '1h' });
    });

    beforeEach((done) => {
        socket = io(`http://localhost:${port}`, {
            auth: {
                token: token,
            },
            ackTimeout: 1000,
            reconnectionDelay: 0,
            timeout: 1000,
        });
        socket.on('connect', () => {
            done();
        });
    });

    afterEach(() => {
        if (socket.connected) {
            socket.disconnect();
        }
    });

    afterAll(async () => {
        ioServer.close();
        httpServer.close();
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('should connect to the socket', (done) => {
        expect(socket.connected).toBe(true);
        done();
    });

    it('should handle client disconnect event', (done) => {
        socket.on('disconnect', () => {
            expect(socket.connected).toBe(false);
            done();
        });
        socket.disconnect();
    });

    it('should check if user is online', () => {
        socketHandler.connectedUsers.set(user1._id.toString(), socket.id!);
        const isOnline = socketHandler.isUserOnline(user1._id.toString());
        expect(isOnline).toBe(true);
    });

    it('should emit to a specific user', (done) => {
        socketHandler.connectedUsers.set(user2._id.toString(), socket.id!);
        socket.on('testEvent', (data) => {
            expect(data).toBe('testData');
            done();
        });
        socketHandler.emitToUser('testEvent', user2._id.toString(), 'testData');
    });

    it('should broadcast to everyone', (done) => {
        const socket2 = io(`http://localhost:${port}`, {
            auth: {
                token: token,
            },
        });
        socket2.on('connect', () => {
            socket2.on('testEvent', (data) => {
                expect(data).toBe('testData');
                socket2.disconnect();
                done();
            });
            socketHandler.broadcastToEveryone('testEvent', 'testData');
        });
    });

    it('should get socket from user id', () => {
        socketHandler.connectedUsers.set(user1._id.toString(), socket.id!);
        const retrievedSocket = socketHandler.getSocketFromUserId(user1._id.toString());
        expect(retrievedSocket).toBeDefined();
    });

    it('should get IO instance', () => {
        const ioInstance = socketHandler.getIO();
        expect(ioInstance).toBeDefined();
    });

    it('should remove user from connected users', () => {
        socketHandler.connectedUsers.set(user1._id.toString(), socket.id!);
        expect(socketHandler.isUserOnline(user1._id.toString())).toBe(true);
        socketHandler.removeUserFromConnectedUsers(user1._id.toString());
        const isOnline = socketHandler.isUserOnline(user1._id.toString());
        expect(isOnline).toBe(false);
    });
});
