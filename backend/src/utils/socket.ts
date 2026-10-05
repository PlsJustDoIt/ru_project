// services/socketHandler.service.ts
import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';
import logger from './logger.js';
import jwt from 'jsonwebtoken';
import { instrument } from '@socket.io/admin-ui';
import { jwtAccessSecret } from '../config.js';

/**
 * Room Socket.IO personnelle d'un utilisateur : toutes ses sockets (téléphone,
 * web, plusieurs onglets...) la rejoignent à la connexion. Permet de cibler un
 * utilisateur sans dépendre d'un unique socket.id.
 */
export const userRoom = (userId: string) => `user:${userId}`;

export class SocketHandler {
    private io: SocketIOServer | null = null;
    /** userId -> ensemble des socket.id connectés pour cet utilisateur. */
    connectedUsers = new Map<string, Set<string>>();

    initialize(server: HTTPServer, isProduction: boolean): void {
        try {
            const allowedOrigins = process.env.CORS_ORIGINS?.split(',').map(o => o.trim()).filter(Boolean);
            this.io = new SocketIOServer(server, {
                connectionStateRecovery: {},
                cors: {
                    // En production, restreindre aux origines autorisées si fournies.
                    origin: isProduction && allowedOrigins && allowedOrigins.length > 0
                        ? allowedOrigins
                        : (process.env.CLIENT_URL || '*'),
                    methods: ['GET', 'POST'],
                    credentials: true,
                },
            });
            // Admin UI Socket.IO (liste des sockets, rooms, événements) : sans
            // authentification, donc réservée au développement.
            if (!isProduction) {
                instrument(this.io, {
                    auth: false,
                    mode: 'development',
                });
            }

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

                const decoded = jwt.verify(token, jwtAccessSecret) as { id: string };
                socket.data.userId = decoded.id;
                next();
            } catch (error) {
                logger.error('Socket.IO Auth Error:', error);
                next(new Error('Authentication error'));
            }
        });

        this.io.on('connection', (socket: Socket) => {
            const userId: string = socket.data.userId;
            logger.info('User %s connected with socket %s', userId, socket.id);
            this.addConnection(userId, socket.id);
            void socket.join(userRoom(userId));

            socket.on('disconnect', () => {
                logger.info(`User ${userId} disconnected (socket ${socket.id})`);
                const stillOnline = this.removeConnection(userId, socket.id);
                // Hors ligne seulement quand sa dernière socket se ferme.
                if (!stillOnline) {
                    this.io?.emit('userOffline', userId);
                }
            });
        });

        this.io.on('error', (error: Error) => {
            logger.error('Socket.IO Error:', error);
        });
    }

    private addConnection(userId: string, socketId: string): void {
        const sockets = this.connectedUsers.get(userId) ?? new Set<string>();
        sockets.add(socketId);
        this.connectedUsers.set(userId, sockets);
    }

    /** Retire une socket ; renvoie true si l'utilisateur a encore d'autres sockets. */
    private removeConnection(userId: string, socketId: string): boolean {
        const sockets = this.connectedUsers.get(userId);
        if (!sockets) return false;
        sockets.delete(socketId);
        if (sockets.size === 0) {
            this.connectedUsers.delete(userId);
            return false;
        }
        return true;
    }

    public isUserOnline(userId: string): boolean {
        return (this.connectedUsers.get(userId)?.size ?? 0) > 0;
    }

    /** Émet vers toutes les sockets d'un utilisateur. */
    public emitToUser(event: string, userId: string, data: unknown) {
        this.io?.to(userRoom(userId)).emit(event, data);
    }

    public removeUserFromConnectedUsers(userId: string): void {
        this.connectedUsers.delete(userId);
    }

    /**
     * Émet vers une room de chat, sauf vers l'expéditeur [userId] (il a déjà
     * le message via la réponse HTTP). Ne dépend pas de la socket de
     * l'expéditeur : fonctionne même s'il n'est pas connecté en temps réel.
     */
    public emitToRoom(userId: string, event: string, roomName: string, data: unknown) {
        try {
            if (!roomName) {
                throw new Error('Room name is required');
            }
            if (!this.io) {
                throw new Error('Socket.IO server not initialized');
            }
            this.io.to(roomName).except(userRoom(userId)).emit(event, data);
        } catch (error) {
            logger.error('Error in emitToRoom:', error);
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
        const sockets = this.connectedUsers.get(userId);
        if (!sockets || !this.io) return undefined;
        for (const socketId of sockets) {
            const socket = this.io.sockets.sockets.get(socketId);
            if (socket) return socket;
        }
        return undefined;
    }

    getIO(): SocketIOServer {
        if (!this.io) {
            throw new Error('Socket.IO is not initialized!');
        }
        return this.io;
    }
}

export const socketHandler = new SocketHandler();
