import { MongoMemoryServer } from 'mongodb-memory-server';
import { io, Socket } from 'socket.io-client';
import { createServer, Server as HTTPServer } from 'http';
import { Server } from 'socket.io';
import { socketService } from '../../services/socket.js';
import { IUser, generateUser, createUser } from '../../models/user.js';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';

let mongoServer: MongoMemoryServer;

describe('socket service', () => {
    it('should connect to the socket', async () => {
        // TODO
    });
});
describe('socket service', () => {
    let socket: Socket;
    let httpServer: HTTPServer;
    let ioServer: Server;
    let port: number;
    let user1: IUser;
    let user2: IUser;
    // let room: IRoom;
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
        socketService.initialize(httpServer);

        port = 5001;
        httpServer.listen(port, () => {
            console.log(`listening on *:${port}`);
        });

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

    it('should handle join_global_room event', (done) => {
        socket.emit('join_global_room');
        socket.on('room_joined', (data) => {
            expect(data.roomName).toBe('Global');
            done();
        });
    });

    // it('should handle join_friend_room event', (done) => {
    //     socket.emit('join_friend_room', user2._id);
    //     socket.on('room_joined', (data) => {
    //         expect(data.roomName).toBeDefined();
    //         done();
    //     });
    // });

    it('should handle join_room event', (done) => {
        socket.emit('join_room', [user1._id, user2._id]);
        socket.on('room_joined', (data) => {
            expect(data.roomName).toBeDefined();
            done();
        });
    });

    it('should handle disconnect event', (done) => {
        socket.disconnect();
        setTimeout(() => {
            expect(socket.connected).toBe(false);
            done();
        }, 50);
    });

    it('should check if user is online', () => {
        socketService.connectedUsers.set(user1._id.toString(), socket.id!);
        const isOnline = socketService.isUserOnline(user1._id.toString());
        expect(isOnline).toBe(true);
    });

    it('should emit to a specific user', (done) => {
        socketService.connectedUsers.set(user2._id.toString(), socket.id!);
        socket.on('testEvent', (data) => {
            expect(data).toBe('testData');
            done();
        });
        socketService.emitToUser('testEvent', user2._id.toString(), 'testData');
    });

    // it('should emit to a room with socket', (done) => {
    //     socket.join('testRoom');
    //     socket.on('testEvent', (data) => {
    //         expect(data).toBe('testData');
    //         done();
    //     });
    //     socketService.emitToRoomWithSocket(socket!, 'testEvent', 'testRoom', 'testData');
    // });

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
            socketService.broadcastToEveryone('testEvent', 'testData');
        });
    });

    it('should get socket from user id', () => {
        socketService.connectedUsers.set(user1._id.toString(), socket.id!);
        const retrievedSocket = socketService.getSocketFromUserId(user1._id.toString());
        expect(retrievedSocket).toBeDefined();
    });

    it('should get IO instance', () => {
        const ioInstance = socketService.getIO();
        expect(ioInstance).toBeDefined();
    });
});
