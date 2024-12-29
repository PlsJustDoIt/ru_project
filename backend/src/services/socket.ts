// services/socket.service.ts
import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';
import logger from './logger.js';

export class SocketService {
    private io: SocketIOServer | null = null;
    private userSockets = new Map<string, string>();

    initialize(server: HTTPServer): void {
        this.io = new SocketIOServer(server, {
            connectionStateRecovery: {},
            cors: {
                origin: process.env.CLIENT_URL || '*',
                methods: ['GET', 'POST'],
                credentials: true,
            },
        });

        this.setupEventHandlers();
    }

    private setupEventHandlers(): void {
        if (!this.io) return;

        this.io.on('connection', (socket: Socket) => {
            this.handleConnection(socket);
        });

        this.io.on('error', (error: Error) => {
            logger.error('Socket.IO Error:', error);
        });
    }

    private handleConnection(socket: Socket): void {
        console.log('A user connected:', socket.id);

        const token = socket.handshake.query.token as string;
        if (token) {
            this.userSockets.set(token, socket.id);
            console.log(`User ${token} connected with socket ID ${socket.id}`);
        }

        this.setupSocketEventHandlers(socket);
    }

    private setupSocketEventHandlers(socket: Socket): void {
        socket.on('join room', async (roomId: string) => {
            await socket.join(roomId);
        });

        socket.on('leave room', async (roomId: string) => {
            await socket.leave(roomId);
        });

        socket.on('send_message', (data) => {
            if (!data || typeof data !== 'string') {
                return socket.emit('error', 'Invalid message format');
            }
            socket.emit('reply', `Server echo: ${data}`);
            this.io?.emit('receive_message', 'je sais ce que tu vas dire : ' + data);
        });

        socket.on('disconnect', () => {
            console.log('User disconnected:', socket.id);
            this.handleDisconnect(socket);
        });
    }

    private handleDisconnect(socket: Socket): void {
        const token = socket.handshake.query.token as string;
        if (token) {
            this.userSockets.delete(token);
        }
    }

    emitToRoom(roomId: string, event: string, data: unknown): void {
        if (!this.io) {
            throw new Error('Socket.IO is not initialized!');
        }
        this.io.to(roomId).emit(event, data);
    }

    getIO(): SocketIOServer {
        if (!this.io) {
            throw new Error('Socket.IO is not initialized!');
        }
        return this.io;
    }
}

export const socketService = new SocketService();
