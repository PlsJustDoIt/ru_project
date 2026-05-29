import multer from 'multer';
import { dirname, join, extname, basename } from 'path';
import logger from './logger.js';
import sharp from 'sharp';
import { unlink, mkdir } from 'fs/promises';

import { NextFunction, Request, Response } from 'express';
import { bugReportPath, avatarPath } from '../config.js';

(async () => {
    try {
        await mkdir(avatarPath, { recursive: true });
        await mkdir(bugReportPath, { recursive: true });
    } catch (error) {
        logger.error('Error creating upload directory:', error);
    }
})();

const storageAvatar = multer.diskStorage({

    destination: (req, file, cb) => {
        cb(null, avatarPath); // Répertoire où les fichiers seront stockés
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
        // Ne jamais utiliser file.originalname tel quel (traversée de chemin).
        // On génère un nom sûr à partir de l'id utilisateur + timestamp.
        // Seul le PNG est accepté (cf. fileFilter) ; convertAndCompress le passera en .jpg.
        cb(null, `${req.user.id}-${Date.now()}.png`);
    },
});

// Middleware multer.
// La limite de taille est appliquée par l'option `limits` ; `file.size` n'est pas
// disponible dans `fileFilter`, on n'y vérifie donc que le type MIME.
const uploadAvatar = multer({
    storage: storageAvatar,
    limits: { fileSize: 4 * 1024 * 1024 }, // Limite de taille : 4MB
    fileFilter: (req, file, cb) => {
        const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif'];
        cb(null, allowedMimeTypes.includes(file.mimetype));
    },
});

const uploadBugReport = multer({
    storage: storageScreenshotBugReport,
    limits: { fileSize: 4 * 1024 * 1024 }, // Limite de taille : 4MB
    fileFilter: (req, file, cb) => {
        const allowedMimeTypes = ['image/png'];
        cb(null, allowedMimeTypes.includes(file.mimetype));
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
