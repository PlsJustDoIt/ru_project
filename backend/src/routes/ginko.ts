import { Router, Request, Response } from 'express';
import auth from '../middleware/auth.js';
import logger from '../services/logger.js';
import axios, { AxiosResponse } from 'axios';
import dotenv from 'dotenv';
import { TempsInfo } from '../interfaces/tempsInfo.js';
import NodeCache from 'node-cache';
import fs from 'fs';
import path from 'path';

import isProduction from '../config.js';

if (!isProduction) {
    dotenv.config();
}

const cache = new NodeCache({ stdTTL: 60 }); // 1 minute
const router = Router();
const apiKey = process.env.GINKO_API_KEY;
if (!apiKey) {
    throw new Error('Ginko API Key not found');
}
const apiUrl = 'https://api.ginko.voyage';

logger.info('API Key : ' + apiKey);

router.get('/info', auth, async (req: Request, res: Response) => {
    try {
        if (!isProduction) {
            const data = fs.readFileSync(path.join(path.resolve(), 'horaires.json'));
            const horaires = JSON.parse(data.toString());
            return res.json(horaires);
        }

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

        /**
         * Sends a POST request to the specified API endpoint to get the temperature of a location.
         *
         * @constant {AxiosResponse} response - The response from the API call.
         * @param {string} apiUrl - The base URL of the API.
         * @param {string} apiKey - The API key for authentication.
         * @param {string} lieu - The name of the location to get the temperature for.
         * @returns {Promise<AxiosResponse>} - A promise that resolves to the response from the API.
         */
        const response: AxiosResponse = await axios.post(apiUrl + '/TR/getTempsLieu.do', null, {
            params: {
                apiKey: apiKey,
                nom: lieu,
            },
        });

        if (response.status !== 200 && response.data['ok'] == false) {
            logger.error(response.data['msg']);
            return res.status(400).json({ data: response.data['msg'] });
        }

        logger.info('nom exact : ' + response.data['objets']['nomExact']);

        // champ intéressant : nomExact : "string"

        const lignes: { [numLignePublic: string]: { [destination: string]: string[] } } = {};

        (response.data['objets']['listeTemps'] as TempsInfo[]).forEach(({ temps, numLignePublic, destination }) => {
        // Vérifier si la ligne existe déjà dans l'objet
            if (!lignes[numLignePublic]) {
                lignes[numLignePublic] = {};
            }

            // Vérifier si la destination existe déjà pour cette ligne
            if (!lignes[numLignePublic][destination]) {
                lignes[numLignePublic][destination] = [];
            }

            // Ajouter le temps à la destination correspondante
            lignes[numLignePublic][destination].push(temps);
        });

        const result = {
            nomExact: response.data['objets']['nomExact'],
            lignes,
        };

        logger.info('Horaires récupérés : ' + result);
        cache.set(lieu, result);
        // save result in horaire.json
        // const filePath = path.join(path.resolve(), 'horaires.json');
        // fs.writeFileSync(filePath, JSON.stringify(result, null, 2), 'utf-8');
        return res.json(result);
    } catch (err: unknown) {
        logger.error('Impossible de récupérer les horaires : ' + err);
        res.status(500).json({ error: err });
    }
});

export default router;
