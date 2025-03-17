import logger from '../../services/logger.js';

jest.mock('../../services/logger.js', () => ({
    info: jest.fn(),
    error: jest.fn(),
}));
describe('logger service', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });
    it('should log an info message', () => {
        const message = 'This is an info message';
        logger.info(message);
        expect(logger.info).toHaveBeenCalledWith(message);
    });

    it('should log an error message', () => {
        const message = 'This is an error message';
        logger.error(message);
        expect(logger.error).toHaveBeenCalledWith(message);
    });
});
