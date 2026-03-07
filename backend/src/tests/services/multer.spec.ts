import { Request, Response, NextFunction } from 'express';
import { convertAndCompress } from '../../utils/multer.js';
import sharp from 'sharp';
import { unlink } from 'fs/promises';
import logger from '../../utils/logger.js';

jest.mock('sharp', () => {
    const mockSharp = {
        jpeg: jest.fn().mockReturnThis(),
        mozjpeg: jest.fn().mockReturnThis(),
        toFile: jest.fn().mockResolvedValue(undefined),
    };
    return jest.fn(() => mockSharp);
});

jest.mock('fs/promises', () => ({
    unlink: jest.fn().mockResolvedValue(undefined),
}));

describe('convertAndCompress', () => {
    let req: Partial<Request>;
    let res: Partial<Response>;
    let next: NextFunction;
    const mockSharpInstance = {
        jpeg: jest.fn().mockReturnThis(),
        mozjpeg: jest.fn().mockReturnThis(),
        toFile: jest.fn().mockResolvedValue(undefined),
    };

    beforeAll(() => {
        logger.info = jest.fn();
        logger.error = jest.fn();
    });

    afterAll(() => {
        jest.restoreAllMocks();
    });

    beforeEach(() => {
        req = {};
        res = {
            status: jest.fn().mockReturnThis(),
            json: jest.fn(),
        };
        next = jest.fn();
        (sharp as unknown as jest.Mock).mockImplementation(() => mockSharpInstance);
        jest.clearAllMocks();
    });

    it('should call next if no file is present', async () => {
        await convertAndCompress(req as Request, res as Response, next);
        expect(next).toHaveBeenCalled();
    });

    it('should convert and compress the image if the file is not a JPG', async () => {
        req.file = {
            path: 'uploads/test.png',
            originalname: 'test.png',
            mimetype: 'image/png',
            filename: 'test.png',
        } as Express.Multer.File;

        await convertAndCompress(req as Request, res as Response, next);

        expect(sharp).toHaveBeenCalledWith('uploads/test.png');
        expect(mockSharpInstance.jpeg).toHaveBeenCalledWith({ quality: 85, mozjpeg: true });
        expect(mockSharpInstance.toFile).toHaveBeenCalledWith('uploads/test.jpg');
        expect(unlink).toHaveBeenCalledWith('uploads/test.png');
        expect(req.file.path).toBe('uploads/test.jpg');
        expect(req.file.filename).toBe('test.jpg');
        expect(req.file.mimetype).toBe('image/jpeg');
        expect(next).toHaveBeenCalled();
    });

    it('should not convert if the file is already a JPG', async () => {
        req.file = {
            path: 'uploads/test.jpg',
            originalname: 'test.jpg',
            mimetype: 'image/jpeg',
            filename: 'test.jpg',
        } as Express.Multer.File;

        await convertAndCompress(req as Request, res as Response, next);

        expect(sharp).not.toHaveBeenCalled();
        expect(next).toHaveBeenCalled();
    });

    it('should handle errors during conversion', async () => {
        req.file = {
            path: 'uploads/test.png',
            originalname: 'test.png',
            mimetype: 'image/png',
            filename: 'test.png',
        } as Express.Multer.File;
        (sharp as unknown as jest.Mock).mockImplementation(() => {
            return {
                jpeg: jest.fn().mockReturnThis(),
                mozjpeg: jest.fn().mockReturnThis(),
                toFile: jest.fn().mockRejectedValue(new Error('Conversion error')),
            };
        });

        await convertAndCompress(req as Request, res as Response, next);

        expect(res.status).toHaveBeenCalledWith(500);
        expect(res.json).toHaveBeenCalledWith({ error: 'Erreur de traitement de l\'image' });
        expect(next).not.toHaveBeenCalled();
    });
});
