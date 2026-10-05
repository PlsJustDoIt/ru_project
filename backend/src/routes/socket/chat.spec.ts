import request from 'supertest';
import { createServer } from 'http';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import app, { setupRoutes } from '../../app.js';
import User from '../../models/user.js';
import Message from '../../models/message.js';
import Room from '../../models/room.js';
import logger from '../../utils/logger.js';
import { socketHandler } from '../../utils/socket.js';
import { initGlobalRoom, MESSAGES_PAGE_SIZE, MAX_MESSAGE_LENGTH } from './socket.service.js';

let mongoServer: MongoMemoryServer;

type TestUser = { id: string; token: string };

const register = async (username: string): Promise<TestUser> => {
    const res = await request(app).post('/api/auth/register')
        .send({ username, password: 'password123' });
    const me = await request(app).get('/api/users/me')
        .set('authorization', `Bearer ${res.body.accessToken}`);
    return { id: me.body.user.id, token: res.body.accessToken };
};

const makeFriends = async (a: TestUser, b: TestUser) => {
    await User.updateOne({ _id: a.id }, { $addToSet: { friends: b.id } });
    await User.updateOne({ _id: b.id }, { $addToSet: { friends: a.id } });
};

const privateRoom = (a: TestUser, b: TestUser) => [a.id, b.id].sort().join('_');

const send = (user: TestUser, roomName: string, content: string) =>
    request(app).post('/api/socket/send-message')
        .set('authorization', `Bearer ${user.token}`)
        .send({ roomName, content });

const fetchMessages = (user: TestUser, roomName: string, before?: string) =>
    request(app).get('/api/socket/messages')
        .set('authorization', `Bearer ${user.token}`)
        .query({ roomName, ...(before ? { before } : {}) });

describe('Chat REST (accès aux rooms, historique, suppression)', () => {
    let alice: TestUser;
    let bob: TestUser;
    let carol: TestUser;

    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        logger.warn = jest.fn();
        setupRoutes(app);
        // Les émissions temps réel ont besoin d'un serveur Socket.IO initialisé.
        socketHandler.initialize(createServer(), false);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        await initGlobalRoom();

        alice = await register('alice');
        bob = await register('bobby');
        carol = await register('carol');
        await makeFriends(alice, bob);
    });

    afterAll(async () => {
        socketHandler.getIO().close();
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('envoie dans le Global et renvoie l\'id de l\'expéditeur', async () => {
        const res = await send(alice, 'Global', '  salut tout le monde  ');
        expect(res.statusCode).toBe(201);
        expect(res.body.message.content).toBe('salut tout le monde');
        expect(res.body.message.userId).toBe(alice.id);
        expect(res.body.message.username).toBe('alice');

        const history = await fetchMessages(carol, 'Global');
        expect(history.statusCode).toBe(200);
        expect(history.body.messages.map((m: { id: string }) => m.id)).toContain(res.body.message.id);
        expect(history.body.hasMore).toBe(false);
    });

    it('refuse un message vide ou trop long', async () => {
        expect((await send(alice, 'Global', '   ')).statusCode).toBe(400);
        expect((await send(alice, 'Global', 'x'.repeat(MAX_MESSAGE_LENGTH + 1))).statusCode).toBe(400);
    });

    it('crée la room privée au premier message entre amis', async () => {
        const roomName = privateRoom(alice, bob);
        expect(await Room.findOne({ name: roomName })).toBeNull();

        const res = await send(alice, roomName, 'coucou bob');
        expect(res.statusCode).toBe(201);
        expect(await Room.findOne({ name: roomName })).not.toBeNull();

        const history = await fetchMessages(bob, roomName);
        expect(history.statusCode).toBe(200);
        expect(history.body.messages).toHaveLength(1);
    });

    it('refuse d\'ouvrir une conversation avec un non-ami', async () => {
        const res = await send(alice, privateRoom(alice, carol), 'hello');
        expect(res.statusCode).toBe(403);
    });

    it('un tiers ne peut ni lire, ni écrire, ni vider une conversation privée', async () => {
        const roomName = privateRoom(alice, bob);
        expect((await fetchMessages(carol, roomName)).statusCode).toBe(403);
        expect((await send(carol, roomName, 'intrus')).statusCode).toBe(403);
        const clear = await request(app).delete('/api/socket/delete-all-messages')
            .set('authorization', `Bearer ${carol.token}`)
            .query({ roomName });
        expect(clear.statusCode).toBe(403);
    });

    it('seul l\'auteur peut supprimer son message', async () => {
        const roomName = privateRoom(alice, bob);
        const sent = await send(alice, roomName, 'à supprimer');
        const messageId = sent.body.message.id;

        const byBob = await request(app).delete('/api/socket/delete-message')
            .set('authorization', `Bearer ${bob.token}`)
            .query({ roomName, messageId });
        expect(byBob.statusCode).toBe(403);
        expect(await Message.findById(messageId)).not.toBeNull();

        const byAlice = await request(app).delete('/api/socket/delete-message')
            .set('authorization', `Bearer ${alice.token}`)
            .query({ roomName, messageId });
        expect(byAlice.statusCode).toBe(200);
        expect(await Message.findById(messageId)).toBeNull();
    });

    it('un message d\'une autre room ne peut pas être supprimé via une room accessible', async () => {
        const globalMsg = await send(carol, 'Global', 'message de carol');
        const res = await request(app).delete('/api/socket/delete-message')
            .set('authorization', `Bearer ${carol.token}`)
            .query({ roomName: privateRoom(alice, bob), messageId: globalMsg.body.message.id });
        expect(res.statusCode).toBe(403);
    });

    it('vider le Global est réservé aux modérateurs', async () => {
        const res = await request(app).delete('/api/socket/delete-all-messages')
            .set('authorization', `Bearer ${alice.token}`)
            .query({ roomName: 'Global' });
        expect(res.statusCode).toBe(403);
    });

    it('un participant peut vider sa conversation privée', async () => {
        const roomName = privateRoom(alice, bob);
        const res = await request(app).delete('/api/socket/delete-all-messages')
            .set('authorization', `Bearer ${bob.token}`)
            .query({ roomName });
        expect(res.statusCode).toBe(200);
        expect((await fetchMessages(alice, roomName)).body.messages).toHaveLength(0);
    });

    it('renvoie les messages les plus récents (et pagine vers les plus anciens)', async () => {
        const roomName = privateRoom(alice, bob);
        const room = await Room.findOne({ name: roomName });
        const total = MESSAGES_PAGE_SIZE + 5;
        const start = Date.now() - total * 1000;
        await Message.insertMany(Array.from({ length: total }, (_, i) => ({
            content: `msg ${i}`,
            user: alice.id,
            room: room!._id,
            createdAt: new Date(start + i * 1000),
        })));

        const latest = await fetchMessages(bob, roomName);
        expect(latest.statusCode).toBe(200);
        expect(latest.body.messages).toHaveLength(MESSAGES_PAGE_SIZE);
        expect(latest.body.hasMore).toBe(true);
        // Ordre chronologique, et le dernier message est bien le plus récent.
        expect(latest.body.messages[0].content).toBe('msg 5');
        expect(latest.body.messages[MESSAGES_PAGE_SIZE - 1].content).toBe(`msg ${total - 1}`);

        const older = await fetchMessages(bob, roomName, latest.body.messages[0].createdAt);
        expect(older.body.messages.map((m: { content: string }) => m.content))
            .toEqual(['msg 0', 'msg 1', 'msg 2', 'msg 3', 'msg 4']);
        expect(older.body.hasMore).toBe(false);
    });

    it('rejette un paramètre before invalide', async () => {
        const res = await fetchMessages(alice, 'Global', 'pas-une-date');
        expect(res.statusCode).toBe(400);
    });
});
