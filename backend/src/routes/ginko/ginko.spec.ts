import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import axios from 'axios';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import logger from '../../utils/logger.js';

jest.mock('axios'); // Mock the axios library

let mongoServer: MongoMemoryServer;
let accessToken: string;

describe('Ginko Router Tests', () => {
    beforeAll(async () => {
        process.env.GINKO_API_KEY = 'test-api-key';
        logger.info = jest.fn(); // pour mute les logs
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        const res = await request(app)
            .post('/api/auth/register')
            .send({
                username: 'testuser',
                password: 'password123',
            });
        accessToken = res.body.accessToken;
    });

    afterAll(async () => {
        jest.resetAllMocks();
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('should return schedules for a valid lieu', async () => {
        const testLieu = 'TestStop';
        (axios.post as jest.Mock).mockResolvedValueOnce({
            status: 200,
            data: {
                objets: {
                    nomExact: 'Crous Université',
                    listeTemps: [
                        { temps: '5 min', numLignePublic: 'L3', destination: 'Pôle Temis' },
                    ],
                },
            },
        });

        const response = await request(app).get(`/api/ginko/info?lieu=${testLieu}`).set('authorization', `Bearer ${accessToken}`);

        expect(response.status).toBe(200);
        expect(response.body.nomExact).toBe('Crous Université');
        expect(axios.post).toHaveBeenCalledTimes(1);
    });

    // it('should return 400 if lieu is empty', async () => {
    //     const response = await request(app).get('/api/ginko/info');
    //     expect(response.status).toBe(400);
    //     expect(response.body.error).toBe('Le lieu est vide');
    // });

    // it('should handle API error response', async () => {
    //     const errorResponse = {
    //         data: {
    //             ok: false,
    //             msg: 'API Error',
    //         },
    //         status: 200,
    //     };

    //     (axios.post as jest.Mock).mockResolvedValueOnce(errorResponse);

    //     const response = await request(app)
    //         .get(`/api/ginko/info?lieu=TestStop`);

    //     expect(response.status).toBe(400);
    //     expect(response.body.data).toBe('API Error');
    // });

    // it('should format response data correctly', async () => {
    //     (axios.post as jest.Mock).mockResolvedValueOnce(mockApiResponse);

    //     const response = await request(app)
    //         .get(`/api/ginko/info?lieu=TestStop`);

    //     expect(response.status).toBe(200);
    //     expect(response.body).toEqual({
    //         nomExact: 'Test Stop',
    //         lignes: {
    //             L1: {
    //                 'Destination A': ['5 min', '10 min'],
    //             },
    //         },
    //     });
    // });
});
