import { Request, Response } from 'express';

jest.mock('../config.js', () => ({
    apiPublicUrl: 'https://api.ru.leomaugeri.fr',
}));

import { handleImageRequest } from './imageHandler.js';

describe('handleImageRequest', () => {
    const buildRes = () => {
        const res = { redirect: jest.fn() } as unknown as Response;
        return res;
    };

    it('redirects to an absolute URL under /api/uploads for a bare file path', () => {
        const req = { params: { path: 'avatar/foo.jpg' } } as unknown as Request;
        const res = buildRes();

        handleImageRequest(req, res);

        expect(res.redirect).toHaveBeenCalledWith(
            'https://api.ru.leomaugeri.fr/api/uploads/avatar/foo.jpg',
        );
    });

    it('redirects to an absolute URL preserving a path that already starts with uploads/', () => {
        const req = { params: { path: 'uploads/avatar/foo.jpg' } } as unknown as Request;
        const res = buildRes();

        handleImageRequest(req, res);

        expect(res.redirect).toHaveBeenCalledWith(
            'https://api.ru.leomaugeri.fr/uploads/avatar/foo.jpg',
        );
    });

    it('joins an array path param with slashes', () => {
        const req = { params: { path: ['avatar', 'foo.jpg'] } } as unknown as Request;
        const res = buildRes();

        handleImageRequest(req, res);

        expect(res.redirect).toHaveBeenCalledWith(
            'https://api.ru.leomaugeri.fr/api/uploads/avatar/foo.jpg',
        );
    });
});
