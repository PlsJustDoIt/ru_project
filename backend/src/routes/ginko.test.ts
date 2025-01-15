import { describe, expect, test, beforeAll, afterAll, jest } from '@jest/globals';
import axios from 'axios';
import request from 'supertest';
import express from 'express';
import ginkoRouter from './ginko.js';

jest.mock('axios');
jest.mock('../middleware/auth', () => jest.fn((req, res, next) => next()));

const app = express();
app.use('/api', ginkoRouter);

describe('Ginko Router Tests', () => {
    const mockApiResponse = {
        data: {
            ok: true,
            objets: {
                nomExact: 'Test Stop',
                listeTemps: [
                    {
                        temps: '5 min',
                        numLignePublic: 'L1',
                        destination: 'Destination A',
                    },
                    {
                        temps: '10 min',
                        numLignePublic: 'L1',
                        destination: 'Destination A',
                    },
                ],
            },
        },
        status: 200,
    };

    beforeAll(() => {
        process.env.GINKO_API_KEY = 'test-api-key';
    });

    afterAll(() => {
        jest.resetAllMocks();
    });

    test('should return cached data if available', async () => {
        const testLieu = 'TestStop';
        (axios.post as jest.Mock).mockResolvedValueOnce(mockApiResponse);

        // First call to populate cache
        await request(app).get(`/api/info?lieu=${testLieu}`);

        // Second call should use cached data
        const response = await request(app).get(`/api/info?lieu=${testLieu}`);

        expect(response.status).toBe(200);
        expect(response.body.nomExact).toBe('Test Stop');
        expect(axios.post).toHaveBeenCalledTimes(1);
    });

    test('should return 400 if lieu is empty', async () => {
        const response = await request(app).get('/api/info');
        expect(response.status).toBe(400);
        expect(response.body.error).toBe('Le lieu est vide');
    });

    test('should handle API error response', async () => {
        const errorResponse = {
            data: {
                ok: false,
                msg: 'API Error',
            },
            status: 200,
        };

        (axios.post as jest.Mock).mockResolvedValueOnce(errorResponse);

        const response = await request(app)
            .get('/api/info?lieu=TestStop');

        expect(response.status).toBe(400);
        expect(response.body.data).toBe('API Error');
    });

    test('should format response data correctly', async () => {
        (axios.post as jest.Mock).mockResolvedValueOnce(mockApiResponse);

        const response = await request(app)
            .get('/api/info?lieu=TestStop');

        expect(response.status).toBe(200);
        expect(response.body).toEqual({
            nomExact: 'Test Stop',
            lignes: {
                L1: {
                    'Destination A': ['5 min', '10 min'],
                },
            },
        });
    });
});
