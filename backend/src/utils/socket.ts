// services/socketHandler.service.ts
import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';
import logger from './logger.js';
import jwt from 'jsonwebtoken';
import { instrument } from '@socket.io/admin-ui';

export class SocketHandler {
    private io: SocketIOServer | null = null;
    connectedUsers = new Map<string, string>();

    initialize(server: HTTPServer, isProduction: boolean): void {
        try {
            this.io = new SocketIOServer(server, {
                connectionStateRecovery: {},
                cors: {
                    origin: process.env.CLIENT_URL || '*',
                    methods: ['GET', 'POST'],
                    credentials: true,
                },
            });
            instrument(this.io, {
                auth: false,
                mode: isProduction ? 'production' : 'development',
            });

            this.setupEventHandlers();
        } catch (error) {
            logger.error('Failed to initialize Socket.IO:', error);
        }
    }

    private setupEventHandlers(): void {
        if (!this.io) return;

        this.io.use(async (socket: Socket, next) => {
            try {
                const token = socket.handshake.auth.token || socket.handshake.query.token;
                if (!token) {
                    return next(new Error('Authentication error'));
                }

                const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET as jwt.Secret) as { id: string };
                socket.data.userId = decoded.id;
                next();
            } catch (error) {
                logger.error('Socket.IO Auth Error:', error);
                next(new Error(error as string));
            }
        });

        this.io.on('connection', (socket: Socket) => {
            logger.info('A user connected with socket : %s', socket.id);
            const userId = socket.data.userId;
            this.connectedUsers.set(userId, socket.id);
            logger.info('User %s connected', userId);
            this.setupSocketEventHandlers(socket);
        });

        this.io.on('error', (error: Error) => {
            logger.error('Socket.IO Error:', error);
        });
    }

    private setupSocketEventHandlers(socket: Socket): void {
        socket.on('disconnect', () => {
            const userId = socket.data.userId;
            logger.info(`User ${userId} disconnected`);
            this.connectedUsers.delete(userId);
            this.io?.emit('userOffline', userId);
        });
    }

    public isUserOnline(userId: string): boolean {
        return this.connectedUsers.has(userId);
    }

    public emitToUser(event: string, userId: string, data: unknown) {
        const socketId = this.connectedUsers.get(userId);
        if (socketId) {
            this.io?.to(socketId).emit(event, data, (response: { status: string }) => {
                logger.info('callback response :', response);
                if (response && response.status) {
                    return response.status;
                }
            });
        }
    }

    // public emitToUser(event: string, userId: string, data: unknown) {
    //     const socketId = this.connectedUsers.get(userId);
    //     if (socketId) {
    //         console.log(`🚀 [SERVER] Envoi de ${event} à ${socketId} avec data:`, data);

    //         this.io?.to(socketId).emit(event, data, (response: any) => {
    //             console.log('🔥 [SERVER] Callback reçu du client :', response);

    //             if (response && response.status) {
    //                 console.log('✅ [SERVER] ACK validé avec status:', response.status);
    //             } else {
    //                 console.log('❌ [SERVER] Erreur : ACK reçu mais status est undefined');
    //             }
    //         });
    //     } else {
    //         console.log('⚠️ [SERVER] Aucun socket trouvé pour userId:', userId);
    //     }
    // }

    public removeUserFromConnectedUsers(userId: string): void {
        if (this.connectedUsers.has(userId)) {
            this.connectedUsers.delete(userId);
        }
    }

    public emitToRoom(userId: string, event: string, roomName: string, data: unknown) {
        try {
            if (!roomName) {
                throw new Error('Room name is required');
            }
            const socket = socketHandler.getSocketFromUserId(userId);
            if (!socket) {
                throw Error('Socket not found for user : ' + userId);
            }
            logger.info('trying to %s to room %s with socket %s: %o', event, roomName, socket.id, data);

            socket.to(roomName).emit(event, data, (response: { status: string }) => {
                if (response && response.status) {
                    return response.status;
                }
            });
        } catch (error) {
            logger.error('Error in emitToRoomWithSocket:', error);
        }
    }

    public broadcastToEveryone(event: string, data: unknown): void {
        if (!this.io) {
            throw new Error('Socket.IO server not initialized');
        }

        this.io.emit(event, data);

        // Optional: log the broadcast for debugging
        logger.debug(`Broadcasted ${event}`);
    }

    public getSocketFromUserId(userId: string): Socket | undefined {
        const socketId = this.connectedUsers.get(userId);
        if (!socketId || !this.io) return undefined;
        logger.info('Getting socket for user %s: %s', userId, socketId);
        return this.io.sockets.sockets.get(socketId);
    }

    getIO(): SocketIOServer {
        if (!this.io) {
            throw new Error('Socket.IO is not initialized!');
        }
        return this.io;
    }
}

export const socketHandler = new SocketHandler();
