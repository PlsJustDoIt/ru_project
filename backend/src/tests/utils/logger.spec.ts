import logger from '../../utils/logger.js';

jest.mock('../../utils/logger.js', () => ({
    info: jest.fn(),
    error: jest.fn(),
}));
describe('logger service', () => {
    beforeEach(() => {
        jest.resetAllMocks(); // Reset all mocks before each test
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
