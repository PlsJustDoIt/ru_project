import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';
import { syncRestaurantsFromCrous, fetchRestaurantsFromExternalAPI } from './ru.service.js';

jest.mock('axios');

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const mockedAxios = jest.requireMock('axios') as any;

const restoXml = `<?xml version="1.0" encoding="UTF-8"?>
<root>
<resto id="r135" title="RU Lumière &amp; Tests" opening="010" closing="0" short_desc="Le RU de test" zone="Besançon" type="Restaurant">
<contact><![CDATA[<h2>RU Lumière</h2><p>42 avenue de l'Observatoire, 25000 Besançon<br/><b>Téléphone</b> : 03 81 00 00 00</p>]]></contact>
</resto>
<resto id="r999" title="Cafétéria Test" type="Cafétéria" zone="Belfort">
<contact><![CDATA[<h2>Cafétéria Test</h2><p>1 rue de la Cafét, 90000 Belfort</p>]]></contact>
</resto>
</root>`;

describe('syncRestaurantsFromCrous', () => {
    let mongoServer: MongoMemoryServer;

    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        logger.warn = jest.fn();
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('fetchRestaurantsFromExternalAPI parse le flux (nom, adresse, type, zone)', async () => {
        mockedAxios.get.mockResolvedValueOnce({ status: 200, data: restoXml });
        const restos = await fetchRestaurantsFromExternalAPI();
        expect(restos).toHaveLength(2);

        const ru = restos.find(r => r.restaurantId === 'r135');
        expect(ru?.name).toBe('RU Lumière & Tests'); // entités décodées
        expect(ru?.address).toBe('42 avenue de l\'Observatoire, 25000 Besançon'); // <h2> et tags retirés, coupé au <br/>
        expect(ru?.description).toBe('Le RU de test');
        expect(ru?.type).toBe('Restaurant');
        expect(ru?.zone).toBe('Besançon');

        const cafet = restos.find(r => r.restaurantId === 'r999');
        expect(cafet?.type).toBe('Cafétéria');
        expect(cafet?.address).toBe('1 rue de la Cafét, 90000 Belfort');
    });

    it('upsert : crée les restos manquants sans toucher aux secteurs', async () => {
        mockedAxios.get.mockResolvedValueOnce({ status: 200, data: restoXml });
        await syncRestaurantsFromCrous(true);

        const all = await Restaurant.find();
        expect(all).toHaveLength(2);
        const ru = all.find(r => r.restaurantId === 'r135');
        expect(ru?.sectors).toHaveLength(0);
    });

    it('catalogue récent -> pas de requête réseau (cache ~3 mois)', async () => {
        // Un sync (forcé) vient d'avoir lieu dans le test précédent
        const callsBefore = mockedAxios.get.mock.calls.length;
        const result = await syncRestaurantsFromCrous();
        expect(result.skipped).toBe(true);
        expect(result.synced).toBe(0);
        expect(mockedAxios.get.mock.calls.length).toBe(callsBefore);
    });

    it('force=true court-circuite le contrôle de fraîcheur', async () => {
        const callsBefore = mockedAxios.get.mock.calls.length;
        mockedAxios.get.mockResolvedValueOnce({ status: 200, data: restoXml });
        const result = await syncRestaurantsFromCrous(true);
        expect(result.skipped).toBe(false);
        expect(result.synced).toBe(2);
        expect(mockedAxios.get.mock.calls.length).toBe(callsBefore + 1);
    });

    it('idempotent : met à jour les existants, aucun doublon', async () => {
        // Deuxième run avec un titre différent
        const updatedXml = restoXml.replace('RU Lumière &amp; Tests', 'RU Lumière Renommé');
        mockedAxios.get.mockResolvedValueOnce({ status: 200, data: updatedXml });
        await syncRestaurantsFromCrous(true);

        const all = await Restaurant.find();
        expect(all).toHaveLength(2); // pas de doublon
        const ru = await Restaurant.findOne({ restaurantId: 'r135' });
        expect(ru?.name).toBe('RU Lumière Renommé');
    });

    it('préserve les secteurs existants lors d\'un re-sync', async () => {
        const ru = await Restaurant.findOne({ restaurantId: 'r135' });
        ru!.sectors = [new mongoose.Types.ObjectId()];
        await ru!.save();

        mockedAxios.get.mockResolvedValueOnce({ status: 200, data: restoXml });
        await syncRestaurantsFromCrous(true);

        const after = await Restaurant.findOne({ restaurantId: 'r135' });
        expect(after?.sectors).toHaveLength(1); // secteurs intacts
    });

    it('flux injoignable -> l\'erreur remonte (gérée par l\'appelant)', async () => {
        mockedAxios.get.mockRejectedValueOnce(new Error('timeout'));
        await expect(syncRestaurantsFromCrous(true)).rejects.toThrow('timeout');
    });
});
