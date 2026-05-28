import { Request, Response } from 'express';

export const handleImageRequest = (req: Request, res: Response) => {
    const filePath = Array.isArray(req.params.path) ? req.params.path.join('/') : req.params.path;
    const finalPath = filePath.startsWith('uploads/') ? filePath : `api/uploads/${filePath}`;
    res.redirect(`/${finalPath}`);
};
