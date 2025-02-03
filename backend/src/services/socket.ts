// services/socket.service.ts
import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';
import logger from './logger.js';
import Room, { generatePrivateRoomName } from '../models/room.js';
import User from '../models/user.js';
import { instrument } from '@socket.io/admin-ui';
import jwt from 'jsonwebtoken';

export class SocketService {
    private io: SocketIOServer | null = null;
    // Map des utilisateurs connectés: userId -> socketId
    connectedUsers = new Map<string, string>();

    initialize(server: HTTPServer): void {
        try {
            this.io = new SocketIOServer(server, {
                connectionStateRecovery: {},
                cors: {
                    origin: process.env.CLIENT_URL || '*', // TODO : changer en production
                    methods: ['GET', 'POST'],
                    credentials: true,
                },
            });
            instrument(this.io, {
                auth: false,
                mode: 'development',
            });
            this.initGlobalRoom();
            this.setupEventHandlers();
        } catch (error) {
            logger.error('Failed to initialize Socket.IO:', error);
        }
    }

    // La room globale sert à connecter tous les utilisateurs, et pouvoir faire le lien avec le modèle message
    private async initGlobalRoom() {
        try {
            const globalRoom = await Room.findOne({ name: 'Global' });
            if (!globalRoom) {
                await Room.create({
                    name: 'Global',
                });
            }
        } catch (error) {
            logger.error('Failed to initialize global room:', error);
            throw new Error('Failed to initialize global room');
        }
    }

    private setupEventHandlers(): void {
        if (!this.io) return;

        this.io.use(async (socket: Socket, next) => {
            try {
                const token = socket.handshake.auth.token || socket.handshake.query.token;
                // console.log('Socket.IO Auth Token: %o', token);
                if (!token) {
                    return next(new Error('Authentication error'));
                }

                // Vérifier et décoder le token
                const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET as jwt.Secret) as { id: string };
                socket.data.userId = decoded.id;
                next();
            } catch (error) {
                logger.error('Socket.IO Auth Error:', error);
                next(new Error(error as string));
            }
        });

        this.io.on('connection', (socket: Socket) => {
            this.handleConnection(socket);
        });

        this.io.on('error', (error: Error) => {
            logger.error('Socket.IO Error:', error);
        });
    }

    private handleConnection(socket: Socket): void {
        console.log('A user connected:', socket.id);

        const userId = socket.data.userId;
        // Stocker la connexion
        this.connectedUsers.set(userId, socket.id);
        // Émettre le statut en ligne
        logger.info('User %s connected', userId);
        // this.io?.emit('userOnline', userId);

        this.setupSocketEventHandlers(socket);
    }

    private setupSocketEventHandlers(socket: Socket): void {
        socket.on('join_global_room', async () => {
            try {
                const globalRoom = await Room.findOne({ name: 'Global' });
                if (!globalRoom) {
                    throw new Error('Global room not found');
                }

                logger.info('User %s joining global room %s', socket.id, globalRoom._id.toString());

                await socket.join(globalRoom._id.toString());
                socket.emit('room_joined', { roomId: globalRoom._id.toString() });
            } catch (error) {
                logger.error('Error joining global room:', error);
                socket.emit('error', 'Failed to join global room');
            }
        });

        socket.on('join_room', async (friendId: string) => {
            try {
                if (!friendId) {
                    throw new Error('Friend ID is required');
                }

                const friend = await User.findById(friendId);
                if (!friend) {
                    return socket.emit('error', 'Friend not found');
                }

                const userId = socket.data.userId;

                // Vérifier si c'est bien un ami
                const user = await User.findById(userId);
                if (!user) {
                    return socket.emit('error', 'User not found');
                }

                if (!user.friends.includes(friend._id)) {
                    return socket.emit('error', 'Not a friend');
                }

                // Créer ou récupérer la room privée
                const room = await Room.findOne({
                    participants: {
                        $all: [userId, friendId],
                        $size: 2,
                    },
                });

                let roomId: string;

                if (room) {
                    roomId = room.name; // très important
                } else {
                    const roomName = generatePrivateRoomName(userId, friendId);
                    const newRoom = await Room.create({
                        participants: [userId, friendId],
                        name: roomName,
                    });
                    roomId = newRoom.name;
                }

                await socket.join(roomId);
                socket.emit('room_joined', { roomId }); // très important
            } catch (error) {
                logger.error('Error joining room:', error);
                socket.emit('error', 'Failed to join room');
            }
        });

        socket.on('leave_room', async (roomId: string) => {
            await socket.leave(roomId);
            // TODO : finir la fonction
        });

        socket.on('disconnect', () => {
            const userId = socket.data.userId;
            console.log(`User ${userId} disconnected`);

            // Nettoyer la connexion
            this.connectedUsers.delete(userId);

            // Émettre le statut hors ligne
            this.io?.emit('userOffline', userId);
        });
    }

    // Méthodes utilitaires
    public isUserOnline(userId: string): boolean {
        return this.connectedUsers.has(userId);
    }

    public emitToUser(event: string, userId: string, data: unknown): void {
        const socketId = this.connectedUsers.get(userId);
        if (socketId) {
            this.io?.to(socketId).emit(event, data);
        }
    }

    public async emitToRoom(event: string, roomId: string, data: unknown): Promise<void> {
        if (!this.io) {
            throw new Error('Socket.IO server not initialized');
        }

        if (!roomId) {
            throw new Error('Room ID is required');
        }

        logger.info('Emitting %s to room %s : %o', event, roomId, data);

        this.io.to(roomId).emit(event, data);
    }

    public async emitToRoomWithSocket(socket: Socket, event: string, roomId: string, data: unknown): Promise<void> {
        if (!roomId) {
            throw new Error('Room ID is required');
        }

        logger.info('trying to %s to room %s with socket %s: %o', event, roomId, socket.id, data);
        socket.to(roomId).emit(event, data);
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

export const socketService = new SocketService();
