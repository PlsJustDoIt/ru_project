import auth from '../middleware/auth.js';
import { Router, Request, Response } from 'express';
import NodeCache from 'node-cache';
import xml2js from 'xml2js';
import { Menu, MenuXml } from '../interfaces/menu.js';
import logger from '../services/logger.js';
import fs from 'fs';

const router = Router();
const ru_lumiere_id = 'r135';
const api_url = 'http://webservices-v2.crous-mobile.fr:8080/feed/bfc/externe/menu.xml';
const cache = new NodeCache({ stdTTL: 604800 }); // 1 semaine

const apiDoc = {
    message: 'API pour récupérer les prochains repas du ru lumière',
    author: {
        name: 'Léo Maugeri',
        email: 'leomaugeri25@gmail.com',
    },
    version: '1.0.0',
    data: {
        static: [
            {
                name: 'Menus',
                description: 'Récupère les menus du RU Lumière',
                method: 'GET',
                endpoint: '/menus',
            },
        ],
    },
};

function decodeHtmlEntities(text: string) {
    return text.replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&');
}

// Fonction récursive pour décoder les valeurs dans un objet JSON
function decodeJsonValues(obj: any): any {
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

/*
<![CDATA[
<h2>midi</h2><h4>Structure fermée du Lundi 23 Décembre 2024 au Vendredi 3 Janvier 2025</h4>]]>
 */
function extractFermeture(html: string): string | boolean {
    const regexFermeture = new RegExp('<h4>Structure fermée du (.*?)</h4>', 'i');
    const fermetureMatch = html.match(regexFermeture);
    if (fermetureMatch) {
        return fermetureMatch[1];
    }
    return false;
}

// Fonction pour transformer un objet <menu> en objet Menu
function transformToMenu(menu: MenuXml): Menu {
    const html = menu._; // Contenu HTML
    const date = menu.$.date; // Date du menu

    return {
        'Entrées': extractPlats(html, 'Entrées'),
        'Cuisine traditionnelle': extractPlats(html, 'Cuisine traditionnelle'),
        'Menu végétalien': extractPlats(html, 'Menu végétalien'),
        'Pizza': extractPlats(html, 'Pizza'),
        'Cuisine italienne': extractPlats(html, 'Cuisine italienne'),
        'Grill': extractPlats(html, 'Grill'),
        'date': date, // On récupère la date du menu
        'Fermeture': extractFermeture(html), // On récupère la date de fermeture si il y en a une
    };
}

// Fonction pour récupérer les menus de l'API externe
async function fetchMenusFromExternalAPI() {
    try {
        // // L'URL de l'API qui retourne le document XML des menus
        // const response: AxiosResponse = await axios.get(api_url);
        // if (response.status !== 200) {
        //     throw new Error('Erreur lors de la récupération des menus');
        // }
        // const xmlData = response.data;
        // // ecrire le contenu du fichier xml dans un fichier menus.xml
        // fs.writeFileSync('menus.xml', xmlData, 'utf-8');

        const xmlData = fs.readFileSync('menus.xml', 'utf-8'); // solution temporaire pour éviter de faire des appels à l'API

        // Conversion du XML en objet JS
        const parser = new xml2js.Parser({
            explicitArray: false,
            preserveChildrenOrder: true, // Conserve l'ordre des enfants XML
        });
        const result = await parser.parseStringPromise(xmlData);
        const restaurants = result.root.resto;
        const restoR135 = restaurants.find((resto: { $: { id: string } }) => resto.$.id === ru_lumiere_id);
        const menus = decodeJsonValues(restoR135.menu);

        const transformedMenus: Menu[] = menus.map((menu: MenuXml) => transformToMenu(menu));
        return transformedMenus;
    } catch (error) {
        console.error('Erreur lors de la récupération des menus:', error);
        throw error;
    }
}

router.get('/', (req: Request, res: Response) => {
    res.send(apiDoc);
},
);

router.get('/menus', auth, async (req: Request, res: Response) => {
    try {
        // On vérifie si les menus sont en cache
        const cachedMenus: Menu[] | undefined = cache.get('menus');
        if (cachedMenus) {
            logger.info('Les menus sont en cache');
            return res.json(cachedMenus);
        }

        // Si les menus ne sont pas en cache, on les récupère de l'API externe
        const menus = await fetchMenusFromExternalAPI();

        // On met les menus en cache pour 1 heure
        cache.set('menus', menus);
        logger.info(menus);
        res.json(menus);
    } catch (error) {
        console.error('Erreur lors de la récupération des menus:', error);
        res.status(500).send('Erreur lors de la récupération des menus');
    }
},
);

export default router;
