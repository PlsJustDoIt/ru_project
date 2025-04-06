import { Request, Response } from 'express';

export const handleImageRequest = (req: Request, res: Response) => {
    const filePath = req.params[0];
    const finalPath = filePath.startsWith('uploads/') ? filePath : `api/uploads/${filePath}`;
    res.redirect(`/${finalPath}`);
};
