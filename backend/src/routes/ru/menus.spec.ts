import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import logger from '../../utils/logger.js';
import { menuCache } from './ru.controller.js';
import { ru_lumiere_id } from './ru.service.js';

jest.mock('axios');

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const mockedAxios = jest.requireMock('axios') as any;

let mongoServer: MongoMemoryServer;

const menuXml = (restos: string) => `<?xml version="1.0" encoding="UTF-8"?>
<root>
${restos}
</root>`;

const dateOffset = (days: number) => new Date(Date.now() + days * 86400000).toISOString().split('T')[0];

// Le controller comble les jours ouverts manquants : on retrouve une date précise
type DayMenu = { date: string; fermeture?: string; plats?: Record<string, string[]> };
const menuOf = (menus: DayMenu[], date: string): DayMenu | undefined =>
    menus.find(m => m.date === date);

const restoWithMenus = (id: string, plat: string, date1: string, date2: string) => {
    const day = () => `<![CDATA[<h2>midi</h2><h4>Entrées</h4><ul class="liste-plats"><li>${plat}</li></ul><h4>Cuisine traditionnelle</h4><ul class="liste-plats"><li>menu non communiqué</li></ul><h4>Menu végétalien</h4><ul class="liste-plats"><li>menu non communiqué</li></ul><h4>Pizza</h4><ul class="liste-plats"><li>menu non communiqué</li></ul><h4>Cuisine italienne</h4><ul class="liste-plats"><li>menu non communiqué</li></ul><h4>Grill</h4><ul class="liste-plats"><li>menu non communiqué</li></ul>]]>`;
    return `<resto id="${id}">
<menu date="${date1}">${day()}</menu>
<menu date="${date2}"><![CDATA[<h2>midi</h2><h4>fermeture exceptionnelle</h4>]]></menu>
</resto>`;
};

describe('GET /api/ru/menus par restaurant', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        logger.warn = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
    });

    beforeEach(() => {
        mockedAxios.get.mockReset();
        menuCache.flushAll();
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('flux injoignable -> repli sur le fixture local (r135 présent)', async () => {
        mockedAxios.get.mockRejectedValueOnce(new Error('network down'));
        const res = await request(app).get('/api/ru/menus');
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body.menus)).toBe(true);
        expect(res.body.menus.length).toBeGreaterThan(0);
    });

    it('?restaurantId=rXXX -> renvoie les menus de CE restaurant', async () => {
        const d1 = dateOffset(1);
        const d2 = dateOffset(2);
        mockedAxios.get.mockResolvedValue({
            status: 200,
            data: menuXml(restoWithMenus('r501', 'Salade de tomates', d1, d2)),
        });
        const res = await request(app).get('/api/ru/menus?restaurantId=r501');
        expect(res.statusCode).toBe(200);
        const jour1 = menuOf(res.body.menus, d1);
        expect(jour1?.plats?.['Entrées']).toEqual(['Salade de tomates']);
        // 2e jour : un seul <h4> -> interprété comme une fermeture
        const jour2 = menuOf(res.body.menus, d2);
        expect(jour2?.fermeture).toBe('fermeture exceptionnelle');
    });

    it('deux restos du même flux -> chacun son menu avec UN SEUL appel réseau', async () => {
        const d1 = dateOffset(3);
        const d2 = dateOffset(4);
        mockedAxios.get.mockResolvedValue({
            status: 200,
            data: menuXml(
                restoWithMenus('r601', 'Pizza royale', d1, d2) + '\n' + restoWithMenus('r602', 'Quiche lorraine', d1, d2),
            ),
        });
        const resA = await request(app).get('/api/ru/menus?restaurantId=r601');
        expect(resA.statusCode).toBe(200);
        expect(menuOf(resA.body.menus, d1)?.plats?.['Entrées']).toEqual(['Pizza royale']);

        const callsAfterFirst = mockedAxios.get.mock.calls.length;
        const resB = await request(app).get('/api/ru/menus?restaurantId=r602');
        expect(resB.statusCode).toBe(200);
        expect(menuOf(resB.body.menus, d1)?.plats?.['Entrées']).toEqual(['Quiche lorraine']);
        // Le flux complet est partagé : pas de 2e appel pour l'autre resto
        expect(mockedAxios.get.mock.calls.length).toBe(callsAfterFirst);
    });

    it('resto absent du flux -> 404', async () => {
        mockedAxios.get.mockResolvedValue({
            status: 200,
            data: menuXml(restoWithMenus('r701', 'Velouté', dateOffset(5), dateOffset(6))),
        });
        const res = await request(app).get('/api/ru/menus?restaurantId=r999');
        expect(res.statusCode).toBe(404);
    });

    it('format d\'id invalide -> 400 sans appel réseau', async () => {
        const res = await request(app).get('/api/ru/menus?restaurantId=pasunid');
        expect(res.statusCode).toBe(400);
        expect(mockedAxios.get.mock.calls.length).toBe(0);
    });

    it('les menus sont mis en cache : un seul appel réseau pour deux requêtes', async () => {
        const d1 = dateOffset(7);
        const d2 = dateOffset(8);
        mockedAxios.get.mockResolvedValue({
            status: 200,
            data: menuXml(restoWithMenus('r801', 'Ratatouille', d1, d2)),
        });
        const first = await request(app).get('/api/ru/menus?restaurantId=r801');
        expect(first.statusCode).toBe(200);
        expect(mockedAxios.get.mock.calls.length).toBe(1);

        const second = await request(app).get('/api/ru/menus?restaurantId=r801');
        expect(second.statusCode).toBe(200);
        expect(second.body).toEqual(first.body);
        expect(mockedAxios.get.mock.calls.length).toBe(1); // servi du cache
    });

    it('TTL : menus en cache 1 jour par resto, flux brut partagé 1 h max', async () => {
        const d1 = dateOffset(9);
        const d2 = dateOffset(10);
        mockedAxios.get.mockResolvedValue({
            status: 200,
            data: menuXml(restoWithMenus('r901', 'Couscous', d1, d2)),
        });
        const res = await request(app).get('/api/ru/menus?restaurantId=r901');
        expect(res.statusCode).toBe(200);

        const now = Date.now();
        const restoTtl = menuCache.getTtl('menus:r901')! - now;
        expect(restoTtl).toBeGreaterThan(86_300_000); // ~24 h
        expect(restoTtl).toBeLessThanOrEqual(86_400_000);

        const feedTtl = menuCache.getTtl('menufeed')! - now;
        expect(feedTtl).toBeGreaterThan(3_500_000); // ~1 h
        expect(feedTtl).toBeLessThanOrEqual(3_600_000);
    });

    it('l\'id par défaut reste RU Lumière (' + ru_lumiere_id + ')', async () => {
        expect(ru_lumiere_id).toBe('r135');
    });

    describe('formats réels du flux CROUS', () => {
        const fetchFormat = async (restoXmlBody: string, restoId: string) => {
            mockedAxios.get.mockResolvedValue({ status: 200, data: menuXml(restoXmlBody) });
            const res = await request(app).get(`/api/ru/menus?restaurantId=${restoId}`);
            expect(res.statusCode).toBe(200);
            return res.body.menus;
        };

        it('menu à UNE catégorie avec liste : ce n\'est PAS une fermeture (cafétéria "Chauds du jour")', async () => {
            const d = dateOffset(11);
            const menus = await fetchFormat(
                `<resto id="r101"><menu date="${d}"><![CDATA[<h2>midi</h2><h4>Chauds du jour</h4><ul class="liste-plats"><li>Quiche lorraine</li><li>Petits pois</li></ul>]]></menu></resto>`,
                'r101',
            );
            const jour = menuOf(menus, d);
            expect(jour?.fermeture).toBeUndefined();
            expect(jour?.plats?.['Chauds du jour']).toEqual(['Quiche lorraine', 'Petits pois']);
        });

        it('catégories libres quel que soit le resto (étages, salles, cafétéria...)', async () => {
            const d = dateOffset(12);
            const cdata = `<![CDATA[<h2>midi</h2><h4>1er étage</h4><ul class="liste-plats"><li>Blanquette de veau</li></ul><h4>ARSENAL</h4><ul class="liste-plats"><li>Pizzas</li></ul><h4>CAF Sandwichs</h4><ul class="liste-plats"><li>Sandwich jambon-beurre</li></ul><h4>fromage et desserts</h4><ul class="liste-plats"><li>Yaourt</li></ul>]]>`;
            const menus = await fetchFormat(
                `<resto id="r102"><menu date="${d}">${cdata}</menu></resto>`,
                'r102',
            );
            const plats = menuOf(menus, d)?.plats;
            expect(plats?.['1er étage']).toEqual(['Blanquette de veau']);
            expect(plats?.['ARSENAL']).toEqual(['Pizzas']);
            expect(plats?.['CAF Sandwichs']).toEqual(['Sandwich jambon-beurre']);
            expect(plats?.['fromage et desserts']).toEqual(['Yaourt']);
        });

        it('services midi ET soir : catégories préfixées par service', async () => {
            const d = dateOffset(13);
            const menus = await fetchFormat(
                `<resto id="r103"><menu date="${d}"><![CDATA[<h2>midi</h2><h4>Entrées</h4><ul><li>Salade</li></ul><h2>soir</h2><h4>Plats du soir</h4><ul><li>Omelette</li></ul>]]></menu></resto>`,
                'r103',
            );
            const plats = menuOf(menus, d)?.plats;
            expect(plats?.['Midi — Entrées']).toEqual(['Salade']);
            expect(plats?.['Soir — Plats du soir']).toEqual(['Omelette']);
        });

        it('message de fermeture "Structure fermée du ..." -> fermeture', async () => {
            const d = dateOffset(14);
            const menus = await fetchFormat(
                `<resto id="r104"><menu date="${d}"><![CDATA[<h2>midi</h2><h4>Structure fermée du Dimanche 26 Juillet 2026 au Lundi 31 Août 2026</h4>]]></menu></resto>`,
                'r104',
            );
            const jour = menuOf(menus, d);
            expect(jour?.fermeture).toContain('Structure fermée');
            expect(jour?.plats).toBeUndefined();
        });

        it('entités HTML et entités numériques décodées dans titres et plats', async () => {
            const d = dateOffset(15);
            const menus = await fetchFormat(
                `<resto id="r105"><menu date="${d}"><![CDATA[<h2>midi</h2><h4>Plats du jour &amp; garnitures</h4><ul><li>Filet mignon &#224; la moutarde</li></ul>]]></menu></resto>`,
                'r105',
            );
            const plats = menuOf(menus, d)?.plats;
            expect(Object.keys(plats ?? [])).toEqual(['Plats du jour & garnitures']);
            expect(plats?.['Plats du jour & garnitures']).toEqual(['Filet mignon à la moutarde']);
        });
    });
});
