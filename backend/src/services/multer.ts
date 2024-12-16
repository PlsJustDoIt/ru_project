import multer from 'multer';
import path from 'path';
import logger from './logger.js';
import sharp from 'sharp';
import fs from 'fs/promises';
import { NextFunction, Request, Response } from 'express';
import isProduction from '../config.js';

let uploadDir;

logger.info(path.resolve());
logger.info(path.dirname(path.resolve()));

if (isProduction) {
    uploadDir = path.dirname(path.resolve()) + '/uploads/avatar';
} else {
    uploadDir = path.resolve() + '/uploads/avatar';
}

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadDir); // Répertoire où les fichiers seront stockés
    },
    filename: (req, file, cb) => {
        const userId = req.user.id; // Assurez-vous que req.user existe et contient un id
        const extension = '.jpg'; // Extension du fichier
        cb(null, `${userId}${extension}`);
    },
});

// Middleware multer
const uploadAvatar = multer({
    storage: storage,
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

// Middleware de conversion et compression
const convertAndCompressAvatar = async (req: Request, res: Response, next: NextFunction) => {
    if (!req.file) {
        return next();
    }

    try {
        const inputPath = req.file.path;
        const originalExtension = path.extname(req.file.originalname).toLowerCase();

        // Ne convertir que si ce n'est pas déjà un JPG
        if (originalExtension !== '.jpg' && req.file.mimetype !== 'image/jpeg') {
            const outputPath = path.join(
                path.dirname(inputPath),
                `${path.basename(inputPath, originalExtension)}.jpg`,
            );

            // Convertir et compresser l'image
            await sharp(inputPath)
                // .resize({
                //     width: 500, // Largeur maximale
                //     height: 500, // Hauteur maximale
                //     fit: 'inside',
                //     withoutEnlargement: true,
                // })
                .jpeg({
                    quality: 85, // Compression à 75%
                    mozjpeg: true, // Utiliser l'encodeur mozjpeg pour de meilleures compressions
                })
                .toFile(outputPath);

            // Supprimer le fichier original
            await fs.unlink(inputPath);

            // Mettre à jour les informations du fichier
            req.file.path = outputPath;
            req.file.filename = path.basename(outputPath);
            req.file.mimetype = 'image/jpeg';
        }

        next();
    } catch (error) {
        logger.error('Erreur de conversion d\'image : ' + error);
        return res.status(500).json({ error: 'Erreur de traitement de l\'image' });
    }
};

export { uploadAvatar, convertAndCompressAvatar };
