import multer from 'multer';
import { dirname, join, extname, basename } from 'path';
import logger from './logger.js';
import sharp from 'sharp';
import { mkdir, unlink } from 'fs/promises';
import { NextFunction, Request, Response } from 'express';
import { uploadsPath, bugReportPath } from '../config.js';

(async () => {
    try {
        await mkdir(uploadsPath, { recursive: true });
        await mkdir(bugReportPath, { recursive: true });
    } catch (error) {
        logger.error('Error creating upload directory:', error);
    }
})();

const storageAvatar = multer.diskStorage({

    destination: (req, file, cb) => {
        cb(null, uploadsPath); // Répertoire où les fichiers seront stockés
    },
    filename: (req, file, cb) => {
        const userId = req.user.id; // Assurez-vous que req.user existe et contient un id
        const extension = '.jpg'; // Extension du fichier
        cb(null, `${userId}${extension}`);
    },
});

const storageScreenshotBugReport = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, bugReportPath); // Répertoire où les fichiers seront stockés
    },
    filename: (req, file, cb) => {
        logger.info(file);
        logger.info(req.body);
        cb(null, `${file.originalname}`);
    },
});

// Middleware multer
const uploadAvatar = multer({
    storage: storageAvatar,
    limits: { fileSize: 4 * 1024 * 1024 }, // Limite de taille : 4MB
    fileFilter: (req, file, cb) => {
        const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif'];
        if (file.size > 4 * 1024 * 1024) {
            cb(null, false);
        }
        if (allowedMimeTypes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(null, false);
        }
    },

});

const uploadBugReport = multer({
    storage: storageScreenshotBugReport,
    limits: { fileSize: 4 * 1024 * 1024 }, // Limite de taille : 4MB
    fileFilter: (req, file, cb) => {
        const allowedMimeTypes = ['image/png'];
        if (file.size > 4 * 1024 * 1024) {
            cb(null, false);
        }
        if (allowedMimeTypes.includes(file.mimetype)) {
            cb(null, true);
        } else {
            cb(null, false);
        }
    },
});

// Middleware de conversion et compression
const convertAndCompress = async (req: Request, res: Response, next: NextFunction) => {
    if (!req.file) {
        return next();
    }

    try {
        const inputPath = req.file.path;
        const originalExtension = extname(req.file.originalname).toLowerCase();

        // Ne convertir que si ce n'est pas déjà un JPG
        if (originalExtension !== '.jpg' && req.file.mimetype !== 'image/jpeg') {
            const outputPath = join(
                dirname(inputPath),
                `${basename(inputPath, originalExtension)}.jpg`,
            );

            // Convertir et compresser l'image
            await sharp(inputPath)
                .jpeg({
                    quality: 85, // Compression à 75%
                    mozjpeg: true, // Utiliser l'encodeur mozjpeg pour de meilleures compressions
                })
                .toFile(outputPath);

            // Supprimer le fichier original
            await unlink(inputPath);

            // Mettre à jour les informations du fichier
            req.file.path = outputPath;
            req.file.filename = basename(outputPath);
            req.file.mimetype = 'image/jpeg';
        }

        next();
    } catch (error) {
        logger.error('Erreur de conversion d\'image : ' + error);
        return res.status(500).json({ error: 'Erreur de traitement de l\'image' });
    }
};

export { uploadAvatar, convertAndCompress, uploadBugReport };
