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

// Fonction pour extraire les plats du contenu HTML
function extractPlats(html: string, title: string): string[] | 'menu non communiqué' {
    // RegEx pour trouver la section avec le titre donné
    const regexTitle = new RegExp(`<h4>${title}</h4>`, 'i');
    const regexListItems = new RegExp(`<h4>${title}</h4>\\s*<ul[^>]*>(.*?)</ul>`, 'is');

    const titleMatch = html.match(regexTitle);
    if (titleMatch) {
        const listMatch = html.match(regexListItems);
        if (listMatch && listMatch[1]) {
            const items = listMatch[1].match(/<li>(.*?)<\/li>/gi);
            if (items) {
                const plats = items.map(item => item.replace(/<\/?li>/gi, '').trim()).filter(item => item !== '');
                return plats.length === 1 && plats[0] === 'menu non communiqué' ? 'menu non communiqué' : plats;
            }
        }
    }
    return 'menu non communiqué';
}

function extractFermeture(html: string): string | null {
    const countH4 = (html.match(/<h4>/g) || []).length;
    if (countH4 != 1) return null;

    const start = html.indexOf('<h4>');
    const end = html.indexOf('</h4>', start);
    return html.substring(start + 4, end);
}

// Fonction pour transformer un objet <menu> en objet Menu
function transformToMenu(menu: MenuXml): MenuResponse {
    const html = menu._;
    const date = menu.$.date;
    const fermeture = extractFermeture(html);

    if (fermeture == null) {
        return {
            'Entrées': extractPlats(html, 'Entrées'),
            'Cuisine traditionnelle': extractPlats(html, 'Cuisine traditionnelle'),
            'Menu végétalien': extractPlats(html, 'Menu végétalien'),
            'Pizza': extractPlats(html, 'Pizza'),
            'Cuisine italienne': extractPlats(html, 'Cuisine italienne'),
            'Grill': extractPlats(html, 'Grill'),
            'date': date,
        };
    }

    return {
        fermeture: fermeture,
        date: date,
    };
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
