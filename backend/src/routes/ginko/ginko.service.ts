import axios, { AxiosResponse } from 'axios';
import logger from '../../utils/logger.js';
import { TempsInfo } from '../../interfaces/tempsInfo.js';

const apiUrl = 'https://api.ginko.voyage';
const apiKey = process.env.GINKO_API_KEY;
if (!apiKey) {
    throw new Error('Ginko API Key not found');
}

const getTempsLieu = async (lieu: string) => {
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

    logger.info('Horaires récupérés : %o', result);

    return result;
};

export { getTempsLieu };
