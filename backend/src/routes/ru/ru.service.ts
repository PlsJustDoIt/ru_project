import { Parser } from 'xml2js';
import axios from 'axios';
import { MenuResponse, MenuXml } from '../../interfaces/menu.js';
import { readFileSync } from 'fs';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';
import { restaurant, crousResto } from '../../interfaces/restaurant.js';
import Sector from '../../models/sector.js';
import { Types } from 'mongoose';

export const ru_lumiere_id = 'r135';

// Base du flux public CROUS Bourgogne-Franche-Comté :
// - resto.xml : tous les restos (id, nom, adresse, type, zone...)
// - menu.xml  : les menus par resto (groupés par <resto id="rXXX">)
const crous_base_url = 'http://webservices-v2.crous-mobile.fr:8080/feed/bfc/externe/';
const crous_resto_url = `${crous_base_url}resto.xml`;
const crous_menu_url = `${crous_base_url}menu.xml`;

// Le catalogue de restos ne bouge quasiment jamais : on ne re-requête le flux
// que si le dernier sync date de plus de 3 mois.
const RESTAURANT_SYNC_MAX_AGE_MS = 90 * 24 * 60 * 60 * 1000;

async function fetchCrousXml(url: string): Promise<string> {
    const response = await axios.get(url, { timeout: 15000 });
    if (response.status !== 200) {
        throw new Error(`Erreur lors de la récupération du flux CROUS (${url})`);
    }
    return response.data;
}

function decodeHtmlEntities(text: string) {
    return text.replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#0*39;|&apos;/g, '\'')
        .replace(/&nbsp;/g, ' ')
        .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
        .replace(/&amp;/g, '&');
}

// Fonction récursive pour décoder les valeurs dans un objet JSON
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function decodeJsonValues(obj: any) {
    const res = JSON.parse(JSON.stringify(obj)); // On crée une copie de l'objet pour éviter de modifier l'original

    for (const key in res) {
        if (typeof res[key] === 'object') {
            res[key] = decodeJsonValues(res[key]);
        } else {
            res[key] = decodeHtmlEntities(res[key]);
        }
    }

    return res;
}

const MENU_NOT_PROVIDED = /^menu non communiqué$/i;

/** Nettoie un fragment HTML en texte lisible (tags retirés, entités décodées). */
function htmlToText(fragment: string): string {
    return decodeHtmlEntities(
        fragment
            .replace(/<br\s*\/?>/gi, ', ')
            .replace(/<[^>]*>/g, ' '),
    ).replace(/\s+/g, ' ').trim();
}

/**
 * Parse le contenu HTML d'un <menu>, QUEL QUE SOIT le format du resto :
 *   - 0..n services <h2> (midi, soir...)
 *   - 0..n catégories <h4> par service, chacune suivie d'une liste <ul><li>
 *   - fermeture : aucun <ul> => le(s) <h4> portent un message
 *     (ex. "Structure fermée du ...") — un menu à UNE catégorie avec liste
 *     (cafétéria "Chauds du jour") n'est PAS une fermeture.
 *
 * Les titres de catégories sont conservés tels quels (Entrées, Plats du jour,
 * Sandwichs, ARSENAL, 1er étage...) ; quand plusieurs services coexistent,
 * ils sont préfixés ("Soir — Plats du soir").
 */
function parseMenuHtml(htmlContent: string): { fermeture?: string; plats: Record<string, string[]> } {
    const plats: Record<string, string[]> = {};

    // Aucune liste => message de fermeture / d'information
    if (!/<ul[\s>]/i.test(htmlContent)) {
        const firstH4 = htmlContent.match(/<h4>([\s\S]*?)<\/h4>/i);
        const text = htmlToText(firstH4 ? firstH4[1] : htmlContent).replace(/,\s*$/, '');
        return { fermeture: text || 'Restaurant fermé', plats };
    }

    // Découpe par services <h2> (le split avec groupe capturant renvoie
    // [avant?, label1, segment1, label2, segment2...])
    const chunks = htmlContent.split(/<h2>([\s\S]*?)<\/h2>/i);
    const segments: Array<{ label: string; body: string }> = [];
    if (chunks.length === 1) {
        segments.push({ label: '', body: chunks[0] });
    } else {
        if (chunks[0].trim()) {
            segments.push({ label: '', body: chunks[0] });
        }
        for (let i = 1; i < chunks.length - 1; i += 2) {
            segments.push({ label: htmlToText(chunks[i]).toLowerCase(), body: chunks[i + 1] });
        }
    }
    const multiService = segments.filter(s => s.label).length > 1;

    for (const segment of segments) {
        // Découpe le segment par catégories <h4>
        const parts = segment.body.split(/<h4>/i);
        for (const part of parts.slice(1)) {
            const titleEnd = part.indexOf('</h4>');
            if (titleEnd === -1) continue;
            const title = htmlToText(part.slice(0, titleEnd));
            const sectionBody = part.slice(titleEnd + '</h4>'.length);

            const items = [...sectionBody.matchAll(/<li[^>]*>([\s\S]*?)<\/li>/gi)]
                .map(li => htmlToText(li[1]))
                .filter(item => item.length > 0 && !MENU_NOT_PROVIDED.test(item));

            if (!title || items.length === 0) continue;
            const key = multiService && segment.label
                ? `${segment.label.charAt(0).toUpperCase() + segment.label.slice(1)} — ${title}`
                : title;
            plats[key] = [...(plats[key] ?? []), ...items];
        }
    }

    return { plats };
}

// Fonction pour transformer un objet <menu> en objet Menu
function transformToMenu(menu: MenuXml): MenuResponse {
    const date = menu.$.date;
    const { fermeture, plats } = parseMenuHtml(menu._);

    if (fermeture) {
        return { fermeture, date };
    }
    if (Object.keys(plats).length === 0) {
        // Du HTML sans structure exploitable : traité comme une fermeture
        // générique plutôt que perdu.
        return { fermeture: 'Restaurant fermé', date };
    }
    return { date, plats };
}

// Menus de tous les restos du flux, indexés par identifiant CROUS.
// Le flux est récupéré et parsé une seule fois puis partagé entre restos.
async function parseCrousMenus(xmlData: string): Promise<Map<string, MenuResponse[]>> {
    // Conversion du XML en objet JS
    const parser = new Parser({
        explicitArray: false,
        preserveChildrenOrder: true, // Conserve l'ordre des enfants XML
    });
    const result = await parser.parseStringPromise(xmlData);
    const restaurants = result.root.resto;
    if (!restaurants) {
        throw new Error('Flux CROUS invalide : aucun resto trouvé');
    }
    const restoList: Array<{ $: { id: string }; menu?: MenuXml | MenuXml[] }>
        = Array.isArray(restaurants) ? restaurants : [restaurants];

    const menusByResto = new Map<string, MenuResponse[]>();
    for (const resto of restoList) {
        if (!resto.menu) {
            continue; // resto sans aucun menu publié
        }
        const rawMenus = Array.isArray(resto.menu) ? resto.menu : [resto.menu];
        const decoded = decodeJsonValues(rawMenus);
        // On renvoie tous les jours du flux ; le filtrage par date et le comblement
        // des jours fermés sont faits par requête dans le controller (dépendent de `today`).
        menusByResto.set(
            resto.$.id,
            decoded.map((menu: MenuXml) => transformToMenu(menu)),
        );
    }
    return menusByResto;
}

/**
 * Récupère le flux complet des menus CROUS (en direct), avec repli sur le
 * fixture local `menus.xml` si le service est injoignable (dev hors-ligne,
 * panne réseau...). Un seul appel réseau sert ensuite tous les restaurants.
 */
async function fetchAllCrousMenus(): Promise<Map<string, MenuResponse[]>> {
    let xmlData: string;
    try {
        xmlData = await fetchCrousXml(crous_menu_url);
    } catch (error) {
        logger.warn(`Flux CROUS injoignable (${error instanceof Error ? error.message : error}) — repli sur le fixture local menus.xml`);
        xmlData = readFileSync('menus.xml', 'utf-8'); // solution temporaire pour éviter de faire des appels à l'API
    }
    return parseCrousMenus(xmlData);
}

/**
 * Menus d'un seul restaurant. Lève une erreur si le resto est absent du flux.
 */
async function fetchMenusFromExternalAPI(ru_id: string = ru_lumiere_id): Promise<MenuResponse[]> {
    const menusByResto = await fetchAllCrousMenus();
    const menus = menusByResto.get(ru_id);
    if (!menus) {
        throw new Error(`Aucun menu trouvé pour le resto ${ru_id}`);
    }
    return menus;
}

// Extrait l'adresse du bloc <contact> CDATA : "<h2>Nom</h2><p>adresse</p>"
function extractAddress(contactHtml: string): string {
    let html = contactHtml.replace(/<h2>[\s\S]*?<\/h2>/i, '');
    const pMatch = html.match(/<p[^>]*>([\s\S]*?)<\/p>/i);
    if (pMatch) {
        html = pMatch[1];
    }
    html = html.split(/<br\s*\/?>/i)[0];
    return decodeHtmlEntities(html.replace(/<[^>]*>/g, '')).trim();
}

interface RestoXmlAttrs {
    id: string;
    title?: string;
    short_desc?: string;
    zone?: string;
    type?: string;
}
interface RestoXmlElement {
    $: RestoXmlAttrs;
    contact?: string | { _: string };
}

// Parse resto.xml : la liste complète des restos du CROUS BFC
async function fetchRestaurantsFromExternalAPI(): Promise<crousResto[]> {
    const xmlData = await fetchCrousXml(crous_resto_url);
    const parser = new Parser({ explicitArray: false, preserveChildrenOrder: true });
    const result = await parser.parseStringPromise(xmlData);
    const restos: RestoXmlElement[] = [].concat(result.root.resto ?? []);

    return restos
        .filter(resto => resto.$ && typeof resto.$.id === 'string')
        .map((resto) => {
            const contactHtml = typeof resto.contact === 'object' && resto.contact !== null
                ? resto.contact._
                : (resto.contact as string | undefined) ?? '';
            return {
                restaurantId: resto.$.id,
                name: decodeHtmlEntities(resto.$.title ?? resto.$.id),
                address: extractAddress(contactHtml),
                description: decodeHtmlEntities(resto.$.short_desc ?? ''),
                type: resto.$.type,
                zone: resto.$.zone,
            };
        })
        .filter(resto => resto.name.length > 0);
}

/**
 * Synchronise les restaurants depuis le flux CROUS : upsert par identifiant
 * officiel (`restaurantId`). Le catalogue est la source persistante : tant que
 * le dernier sync date de moins de 3 mois, le flux n'est PAS requêté (les
 * restos ne changent quasiment jamais). `force` court-circuite ce contrôle
 * (endpoint admin / première installation).
 * Idempotent — ne touche pas aux secteurs existants.
 */
async function syncRestaurantsFromCrous(force = false): Promise<{ synced: number; skipped: boolean }> {
    if (!force) {
        // `timestamps: true` : updatedAt = date du dernier sync (upsert $set)
        const latest = await Restaurant.findOne().sort({ updatedAt: -1 }).select('updatedAt');
        const ageMs = latest?.updatedAt ? Date.now() - latest.updatedAt.getTime() : Infinity;
        if (ageMs < RESTAURANT_SYNC_MAX_AGE_MS) {
            logger.info('Sync CROUS : catalogue datant de moins de 3 mois, flux non requêté');
            return { synced: 0, skipped: true };
        }
    }

    const restos = await fetchRestaurantsFromExternalAPI();
    for (const resto of restos) {
        await Restaurant.updateOne(
            { restaurantId: resto.restaurantId },
            {
                $set: {
                    name: resto.name,
                    address: resto.address,
                    description: resto.description,
                    ...(resto.type ? { type: resto.type } : {}),
                    ...(resto.zone ? { zone: resto.zone } : {}),
                },
                $setOnInsert: { sectors: [] },
            },
            { upsert: true },
        );
    }
    logger.info(`Sync CROUS : ${restos.length} restaurants synchronisés`);
    return { synced: restos.length, skipped: false };
}

const findRestaurant = async (restaurantId: string, select: string | null = null) => {
    if (select) {
        return await Restaurant.findOne({ restaurantId: restaurantId }).select(select);
    }
    return await Restaurant.findOne({ restaurantId: restaurantId });
};

const findRestaurantById = async (id: Types.ObjectId | undefined, select?: string) => {
    if (select) {
        return await Restaurant.findById(id).select(select);
    }
    return await Restaurant.findById(id);
};

/**
 * Résout un restaurant quel que soit l'identifiant fourni : ObjectId Mongo
 * ou identifiant officiel CROUS ('r135'). Les deux espaces d'ids coexistent
 * (refs utilisateurs historiques = ObjectId, flux CROUS = 'rXXX').
 */
const findRestaurantByAnyId = async (id: string, select: string | null = null) => {
    if (Types.ObjectId.isValid(id)) {
        const byMongoId = await findRestaurantById(new Types.ObjectId(id), select ?? undefined);
        if (byMongoId) {
            return byMongoId;
        }
    }
    return await findRestaurant(id, select);
};

const createRestaurant = async (restaurant: restaurant) => {
    return await Restaurant.create(restaurant);
};

const setupRestaurant = async () => {
    // Check if the restaurant exists and has valid data
    const resto_lumiere = await findRestaurant('r135');

    let shouldClearData = false;

    if (!resto_lumiere) {
        logger.warn('Restaurant RU Lumière not found. Data will be cleared and recreated.');
        shouldClearData = true;
    } else if (!Array.isArray(resto_lumiere.sectors) || resto_lumiere.sectors.length === 0) {
        logger.warn('Restaurant RU Lumière has no sectors. Data will be cleared and recreated.');
        shouldClearData = true;
    }
    // Check if the restaurant has valid data
    if (resto_lumiere && resto_lumiere.sectors.length > 0) {
        const hasInvalidData = (await Promise.all(resto_lumiere.sectors.map(async (sectorId) => {
            // get sector by id
            const sector = await Sector.findById(sectorId);
            return sector === null;
        }))).some(isMissing => isMissing);
        if (hasInvalidData) {
            logger.warn('Restaurant RU Lumière has invalid data. Data will be cleared and recreated.');
            shouldClearData = true;
        }
    }

    if (shouldClearData) {
        // Clear sectors and restaurants
        logger.info('Clearing invalid data...');
        await Sector.deleteMany({});
        await Restaurant.deleteMany({});

        // Recreate the restaurant
        await createRestaurant({
            restaurantId: 'r135',
            name: 'RU Lumière',
            sectors: [],
            address: '42 avenue de l\'Observatoire 25003 Besançon',
            description: 'Restaurant universitaire situé à proximité de la place de la Bourse',
        });
        logger.info('Restaurant RU Lumière created.');
    }

    // Fetch the restaurant again after clearing or if it already exists
    const resto = await findRestaurant('r135');

    // Add sectors if the restaurant exists and has no sectors
    if (resto && resto.sectors.length === 0) {
        const sectors = [
            { position: { x: 10, y: 10 }, size: { width: 20, height: 15 }, name: '1', restaurant: resto._id },
            { position: { x: 40, y: 10 }, size: { width: 20, height: 15 }, name: '2', restaurant: resto._id },
            { position: { x: 70, y: 10 }, size: { width: 20, height: 15 }, name: '3', restaurant: resto._id },
            { position: { x: 10, y: 30 }, size: { width: 20, height: 15 }, name: '4', restaurant: resto._id },
            { position: { x: 70, y: 30 }, size: { width: 20, height: 15 }, name: '5', restaurant: resto._id },
            { position: { x: 10, y: 50 }, size: { width: 20, height: 15 }, name: '6', restaurant: resto._id },
            { position: { x: 70, y: 50 }, size: { width: 20, height: 15 }, name: '7', restaurant: resto._id },
            { position: { x: 10, y: 70 }, size: { width: 20, height: 15 }, name: '8', restaurant: resto._id },
            { position: { x: 70, y: 70 }, size: { width: 20, height: 15 }, name: '9', restaurant: resto._id },
        ];
        const sectorIds = await Promise.all(
            sectors.map(async (sector) => {
                const newSector = await Sector.create(sector);
                return newSector._id;
            }),
        );
        resto.sectors = sectorIds;
        await resto.save();
        logger.info('Sectors created and added to RU Lumière.');
    }
};

const getSectorsFromRestaurant = async (restaurantId: Types.ObjectId) => {
    const restaurant = await findRestaurantById(restaurantId);
    if (!restaurant) {
        throw new Error('Restaurant not found');
    }
    const sectors = await Sector.find({ _id: { $in: restaurant.sectors } });
    // Un resto sans secteur est un état VALIDE depuis que tout le catalogue
    // CROUS est sélectionnable : seul le RU principal en possède.
    return sectors.map(sector => ({
        id: sector._id.toString(),
        position: sector.position,
        size: sector.size,
        sectorId: sector.sectorId,
    }));
};

// Avance d'un jour calendaire (en UTC, pour coller au `today` calculé via toISOString).
function nextDay(date: string): string {
    const d = new Date(date + 'T00:00:00Z');
    d.setUTCDate(d.getUTCDate() + 1);
    return d.toISOString().split('T')[0];
}

// Samedi (6) ou dimanche (0) — en UTC pour rester cohérent avec `nextDay`.
function isWeekend(date: string): boolean {
    const day = new Date(date + 'T00:00:00Z').getUTCDay();
    return day === 0 || day === 6;
}

/**
 * Comble les jours fermés EN SEMAINE : à partir des jours ouverts (déjà filtrés
 * `>= today`), renvoie une plage de `today` jusqu'au dernier jour reçu, en insérant
 * chaque jour de semaine manquant comme `{ date, fermeture: 'Restaurant fermé' }`.
 * Les week-ends ne sont jamais comblés (toujours fermés, inutile de les afficher),
 * mais un menu réel tombant un week-end (RU ouvert le samedi) est conservé.
 * Liste vide un jour de semaine -> un seul jour fermé (aujourd'hui) ; un week-end -> [].
 */
function fillClosedDays(menus: MenuResponse[], today: string): MenuResponse[] {
    const sorted = [...menus].sort((a, b) => a.date.localeCompare(b.date));
    const lastDate = sorted.length > 0 ? sorted[sorted.length - 1].date : today;
    const end = today > lastDate ? today : lastDate;
    const byDate = new Map(sorted.map(m => [m.date, m]));

    const result: MenuResponse[] = [];
    for (let d = today; d <= end; d = nextDay(d)) {
        const existing = byDate.get(d);
        if (existing) {
            result.push(existing); // menu réel : toujours conservé, week-end inclus
        } else if (!isWeekend(d)) {
            result.push({ date: d, fermeture: 'Restaurant fermé' });
        }
    }
    return result;
}

export { fetchMenusFromExternalAPI, fetchAllCrousMenus, fetchRestaurantsFromExternalAPI, syncRestaurantsFromCrous, findRestaurant, findRestaurantById, findRestaurantByAnyId, createRestaurant, setupRestaurant, getSectorsFromRestaurant, fillClosedDays };
