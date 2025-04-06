import axios from 'axios';
import { getTempsLieu } from './ginko.service.js';
import logger from '../../utils/logger.js';

jest.mock('axios'); // Mock the axios library
describe('Ginko service Tests', () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let ginkoApiResponse: any;
    beforeEach(() => {
        ginkoApiResponse = {
            ok: true,
            objets: {
                listeTemps: [
                    {
                        latitude: 47.24853,
                        destination: 'Pôle Temis',
                        couleurTexte: 'FFFFFF',
                        couleurFond: '006AB3',
                        temps: '9 min',
                        aideDecisionAffluence: '',
                        tempsEnSeconde: 540,
                        accessibiliteArret: 0,
                        accessibiliteVehicule: 1,
                        modeTransport: 0,
                        idLigne: '3',
                        tempsHTMLEnAlternance: '',
                        fiable: true,
                        longitude: 5.98644,
                        numVehicule: '526',
                        idInfoTrafic: 0,
                        idArret: 'CROUUNI2',
                        tauxDeCharge: -2,
                        typeDeTemps: 0,
                        precisionDestination: 'par Gare Viotte et Campus',
                        texteAffluence: '',
                        tempsEnMinute: -1,
                        sensAller: false,
                        alternance: false,
                        terminus: 0,
                        affluence: -2,
                        numLignePublic: 'L3',
                        tempsHTML: '<span class="gk-temps">9</span> <span class="gk-mn">min</span>',
                    },
                ],
                latitude: 47.248455,
                nomExact: 'Crous Université',
                longitude: 5.9866357,
            },
        };
    });

    afterEach(() => {
        jest.resetAllMocks(); // Reset all mocks after each test
    });

    beforeAll(async () => {
        logger.info = jest.fn(); // Mock the logger to prevent actual logging
        logger.error = jest.fn(); // Mock the logger to prevent actual logging
    });

    afterAll(async () => {
        jest.resetAllMocks();
    });

    it('should return the correct data structure', async () => {
        (axios.post as jest.Mock).mockResolvedValue({ data: ginkoApiResponse });

        const result = await getTempsLieu('Crous');

        expect(result).toEqual({
            nomExact: 'Crous Université',
            lignes: {
                L3: {
                    'Pôle Temis': ['9 min'],
                },
            },

        });
    });

    it('should handle errors correctly', async () => {
        (axios.post as jest.Mock).mockRejectedValue(new Error('API error'));

        await expect(getTempsLieu('Crous')).rejects.toThrow('API error');
    });
    it('should handle empty response', async () => {
        (axios.post as jest.Mock).mockResolvedValue({ data: { ok: false, msg: 'No data' } });

        await expect(getTempsLieu('Crous')).rejects.toThrow('No data');
    },
    );
    it('should handle empty location', async () => {
        (axios.post as jest.Mock).mockResolvedValue({ data: ginkoApiResponse });

        const result = await getTempsLieu('');

        expect(result).toEqual({
            nomExact: 'Crous Université',
            lignes: {
                L3: {
                    'Pôle Temis': ['9 min'],
                },
            },

        });
    },
    );
    it('should handle API error', async () => {
        (axios.post as jest.Mock).mockResolvedValue({ data: { ok: false, msg: 'API error' } });

        await expect(getTempsLieu('Crous')).rejects.toThrow('API error');
    },
    );

    it('should throw an error if nomExact is empty', async () => {
        ginkoApiResponse.objets.nomExact = '';
        (axios.post as jest.Mock).mockResolvedValue({ data: ginkoApiResponse });
        await expect(getTempsLieu('Crous')).rejects.toThrow('Erreur lors de la récupération des horaires pour Crous');
    });

    it('should throw an error if listeTemps is empty', async () => {
        ginkoApiResponse.objets.listeTemps = [];
        (axios.post as jest.Mock).mockResolvedValue({ data: ginkoApiResponse });
        await expect(getTempsLieu('Crous')).rejects.toThrow('Erreur lors de la récupération des horaires pour Crous');
    });

    it('should throw an error if listeTemps is null', async () => {
        ginkoApiResponse.objets.listeTemps = null;
        (axios.post as jest.Mock).mockResolvedValue({ data: ginkoApiResponse });
        await expect(getTempsLieu('Crous')).rejects.toThrow('Erreur lors de la récupération des horaires pour Crous');
    });

    it('should throw an error if lignes is empty', async () => {
        ginkoApiResponse.objets.listeTemps = [];
        (axios.post as jest.Mock).mockResolvedValue({ data: ginkoApiResponse });
        await expect(getTempsLieu('Crous')).rejects.toThrow('Erreur lors de la récupération des horaires pour Crous');
    },
    );
});
