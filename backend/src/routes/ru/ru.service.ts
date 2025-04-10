import { Parser } from 'xml2js';
import { MenuResponse, MenuXml } from '../../interfaces/menu.js';
import { readFileSync } from 'fs';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';
import { restaurant } from '../../interfaces/restaurant.js';
import Sector from '../../models/sector.js';
const ru_lumiere_id = 'r135';

// eslint-disable-next-line @typescript-eslint/no-unused-vars, unused-imports/no-unused-vars
const api_url = 'http://webservices-v2.crous-mobile.fr:8080/feed/bfc/externe/menu.xml';

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

// Fonction pour récupérer les menus de l'API externe
async function fetchMenusFromExternalAPI(ru_id: string = ru_lumiere_id): Promise<MenuResponse[]> {
    try {
        // // L'URL de l'API qui retourne le document XML des menus
        // const response: AxiosResponse = await axios.get(api_url);
        // if (response.status !== 200) {
        //     throw new Error('Erreur lors de la récupération des menus');
        // }
        // const xmlData = response.data;
        // // ecrire le contenu du fichier xml dans un fichier menus.xml
        // fs.writeFileSync('menus.xml', xmlData, 'utf-8');

        const xmlData = readFileSync('menus.xml', 'utf-8'); // solution temporaire pour éviter de faire des appels à l'API

        // Conversion du XML en objet JS
        const parser = new Parser({
            explicitArray: false,
            preserveChildrenOrder: true, // Conserve l'ordre des enfants XML
        });
        const result = await parser.parseStringPromise(xmlData);
        const restaurants = result.root.resto;
        const resto = restaurants.find((resto: { $: { id: string } }) => resto.$.id === ru_id);
        const menus = decodeJsonValues(resto.menu);
        const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format
        const filteredMenus = menus.filter((menu: MenuXml) => menu.$.date >= today);

        const transformedMenus: MenuResponse[] = filteredMenus.map((menu: MenuXml) => transformToMenu(menu));
        return transformedMenus;
    } catch (error) {
        console.error('Erreur lors de la récupération des menus:', error);
        throw error;
    }
}

const findRestaurant = async (restaurantId: string) => {
    return await Restaurant.findOne({ restaurantId: restaurantId }).populate('sectors');
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
        const hasInvalidData = resto_lumiere.sectors.some((sectorId) => {
            // get sector by id
            const sector = Sector.findById(sectorId);
            if (!sector) {
                logger.warn(`Sector with ID ${sectorId} not found. Data will be cleared and recreated.`);
                return true;
            }
        });
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
            { position: { x: 10, y: 10 }, size: { width: 20, height: 15 }, name: '1' },
            { position: { x: 40, y: 10 }, size: { width: 20, height: 15 }, name: '2' },
            { position: { x: 70, y: 10 }, size: { width: 20, height: 15 }, name: '3' },
            { position: { x: 10, y: 30 }, size: { width: 20, height: 15 }, name: '4' },
            { position: { x: 70, y: 30 }, size: { width: 20, height: 15 }, name: '5' },
            { position: { x: 10, y: 50 }, size: { width: 20, height: 15 }, name: '6' },
            { position: { x: 70, y: 50 }, size: { width: 20, height: 15 }, name: '7' },
            { position: { x: 10, y: 70 }, size: { width: 20, height: 15 }, name: '8' },
            { position: { x: 70, y: 70 }, size: { width: 20, height: 15 }, name: '9' },
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

export { fetchMenusFromExternalAPI, findRestaurant, createRestaurant, setupRestaurant };
