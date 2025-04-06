import axios, { AxiosResponse } from 'axios';
import logger from '../../utils/logger.js';
import { TempsInfo } from '../../interfaces/tempsInfo.js';
import { ginkoApiKey } from '../../config.js';

const apiUrl = 'https://api.ginko.voyage';
const apiKey = ginkoApiKey;
if (!apiKey) {
    throw new Error('Ginko API Key not found');
}

const getTempsLieu = async (lieu: string) => {
    try {
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
            throw new Error(response.data['msg']);
        }

        const infos = { nomExact: response.data['objets']['nomExact'], listeTemps: response.data['objets']['listeTemps'] as TempsInfo[] };
        const result = transformResponse(infos.nomExact, infos.listeTemps);
        logger.info('Horaires récupérés : %o', result);

        return result;
    } catch (error) {
        logger.error('Erreur lors de la récupération des horaires : %o', error);
        throw new Error(`Erreur lors de la récupération des horaires pour ${lieu} : ${error}`);
    }
};

const transformResponse = (nomExact: string, listeTemps: TempsInfo[]) => {
    if (!nomExact) {
        throw new Error('Le nom exact est vide');
    }

    if (!listeTemps || listeTemps.length === 0) {
        throw new Error('Aucun temps trouvé');
    }
    const lignes: { [numLignePublic: string]: { [destination: string]: string[] } } = {};

    listeTemps.forEach(({ temps, numLignePublic, destination }) => {
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

    if (Object.keys(lignes).length === 0) {
        // Si aucune ligne n'est trouvée, on lève une erreur
        throw new Error('Aucune ligne trouvée');
    }

    const result = {
        nomExact,
        lignes,
    };

    return result;
};

export { getTempsLieu };
