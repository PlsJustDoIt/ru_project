import { MongoMemoryServer } from 'mongodb-memory-server';
import logger from '../../services/logger.js';

let mongoServer: MongoMemoryServer;

describe('logger service', () => {
    it('should log an info message', () => {
        logger.info('This is an info message');
    });

    it('should log an error message', () => {
        logger.error('This is an error message');
    });
});
