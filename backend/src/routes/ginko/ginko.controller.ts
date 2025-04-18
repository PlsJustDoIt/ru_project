import { Request, Response } from 'express';
import NodeCache from 'node-cache';
import logger from '../../utils/logger.js';
import { getTempsLieu } from './ginko.service.js';

const cache = new NodeCache({ stdTTL: 60 }); // 1 minute

const getSchedules = async (req: Request, res: Response) => {
    try {
        // if (!isProduction) {
        //     const data = readFileSync(join(resolve(), 'horaires.json'));
        //     const horaires = JSON.parse(data.toString());
        //     return res.json(horaires);
        // }

        const lieu = req.query.lieu as string;
        if (!lieu || lieu.length === 0) {
            logger.error('Le lieu est vide');
            return res.status(400).json({ error: 'Le lieu est vide' });
        }
        const cachedData = cache.get(lieu);
        if (cachedData) {
            logger.info(`Données récupérées depuis le cache pour le lieu : ${lieu}`);
            return res.json(cachedData);
        }

        const result = await getTempsLieu(lieu);
        cache.set(lieu, result);
        return res.json(result);
    } catch (err: unknown) {
        logger.error('Impossible de récupérer les horaires : ', err);
        return res.status(500).json({ error: err });
    }
};

export { getSchedules };
