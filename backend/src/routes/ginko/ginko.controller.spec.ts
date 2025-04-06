import logger from '../../utils/logger.js';
import { getSchedules } from './ginko.controller.js';
import { Request, Response } from 'express';

jest.mock('node-cache', () => {
    const MockNodeCache = jest.fn();
    MockNodeCache.prototype.get = jest.fn();
    MockNodeCache.prototype.set = jest.fn();
    MockNodeCache.prototype.del = jest.fn();
    // ... Mockez toutes les autres méthodes nécessaires

    return MockNodeCache;
});

jest.mock('./ginko.service.js');

import * as ginkoService from './ginko.service.js'; // Importer le module de service

// Importer le module de configuration
import NodeCache from 'node-cache';

jest.mock('axios'); // Mock the axios library
describe('Ginko controller Tests', () => {
    const apiResponse = {
        nomExact: 'Crous Université',
        lignes: {
            7: {
                'Palente Espace Industriel': [
                    '18 min',
                    '42 min',
                ],
                'Hauts du Chazal': [
                    '11 min',
                    '37 min',
                ],
            },
            L3: {
                'Centre-ville - 8 Septembre': [
                    '1 min',
                    '13 min',
                ],
                'Pôle Temis': [
                    '5 min',
                    '21 min',
                ],
            },
        },
    };

    let req: Partial<Request>;
    let res: Partial<Response>;
    let statusMock: jest.Mock;
    let jsonMock: jest.Mock;

    beforeEach(() => {
        jsonMock = jest.fn();
        statusMock = jest.fn().mockReturnValue({ json: jsonMock });
        res = { status: statusMock, json: jsonMock };
        req = {
            body: {
            },
        };
    });

    beforeAll(async () => {
        logger.info = jest.fn(); // Mock the logger to prevent actual logging
        logger.error = jest.fn(); // Mock the logger to prevent actual logging
    });

    afterEach(() => {
        jest.resetAllMocks();
    });

    // afterEach(() => {
    //     jest.resetModules(); // 🔥 Réinitialise les modules après chaque test
    // });

    it('should return the schedules from JSON in dev', async () => {
        req.query = { lieu: 'Crous Université' };
        const cache = new NodeCache();
        cache.get = jest.fn();
        await (getSchedules(req as Request, res as Response, false));
        expect(jsonMock).toHaveBeenCalledWith(apiResponse);
    });

    it('should return 400 if lieu is empty', async () => {
        req.query = { lieu: '' };
        await (getSchedules(req as Request, res as Response, true));
        expect(statusMock).toHaveBeenCalledWith(400);
        expect(jsonMock).toHaveBeenCalledWith({ error: 'Le lieu est vide' });
    });

    it('should return the schedules from service in prod when not cached', async () => {
        req.query = { lieu: 'Crous Université' };
        const cache = new NodeCache();
        cache.get = jest.fn();
        cache.set = jest.fn();
        (ginkoService.getTempsLieu as jest.Mock).mockResolvedValue(apiResponse);
        await (getSchedules(req as Request, res as Response, true));
        expect(jsonMock).toHaveBeenCalledWith(apiResponse);
    });

    it('should return the schedules from service in prod when cached', async () => {
        req.query = { lieu: 'Crous Université' };
        const cache = new NodeCache();
        (cache.get as jest.Mock).mockReturnValue(apiResponse);
        await (getSchedules(req as Request, res as Response, true));
        expect(jsonMock).toHaveBeenCalledWith(apiResponse);
    });

    it('should return 500 if an error occurs', async () => {
        req.query = { lieu: 'Crous Université' };
        const cache = new NodeCache();
        cache.get = jest.fn();
        cache.set = jest.fn();
        (ginkoService.getTempsLieu as jest.Mock).mockRejectedValue(new Error('API error'));
        await (getSchedules(req as Request, res as Response, true));
        expect(statusMock).toHaveBeenCalledWith(500);
        expect(jsonMock).toHaveBeenCalledWith({ error: new Error('API error') });
    });
});
