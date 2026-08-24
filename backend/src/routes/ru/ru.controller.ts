import { Request, Response } from 'express';
import { MenuResponse } from '../../interfaces/menu.js';
import logger from '../../utils/logger.js';
import {
    fetchAllCrousMenus,
    findRestaurantByAnyId,
    getSectorsFromRestaurant,
    fillClosedDays,
    syncRestaurantsFromCrous,
    ru_lumiere_id,
} from './ru.service.js';
import NodeCache from 'node-cache';
import Restaurant from '../../models/restaurant.js';
import { getUserById } from '../user/user.service.js';
import SectorSession from '../../models/sectorSession.js';
import { Types } from 'mongoose';
import friendsInSector from '../../interfaces/friendsInSector.js';
import { isProduction } from '../../config.js';

// Menus CROUS : chaque restaurant est mis en cache 1 jour (les menus sont
// publiés quotidiennement). Le flux brut est partagé entre restos avec une
// fenêtre d'1 h max, pour ne jamais faire N appels réseau pour N restos.
const MENU_CACHE_TTL = 86400;
const RAW_FEED_TTL = 3600;
const menuCache = new NodeCache({ stdTTL: MENU_CACHE_TTL });
export { menuCache };

/**
 * Construit le pipeline d'agrégation des sessions de secteur, groupées par sectorId.
 * Si `userIds` est fourni, on ne renvoie que les sessions de ces utilisateurs
 * (ex. les amis) ; sinon, toutes les sessions des secteurs du restaurant.
 */
const buildSectorSessionsPipeline = (sectors: Types.ObjectId[], userIds?: Types.ObjectId[]) => [
    {
        $match: {
            sector: { $in: sectors },
            ...(userIds ? { user: { $in: userIds } } : {}),
        },
    },
    {
        $lookup: {
            from: 'users',
            localField: 'user',
            foreignField: '_id',
            as: 'userDetails',
        },
    },
    {
        $lookup: {
            from: 'sectors',
            localField: 'sector',
            foreignField: '_id',
            as: 'sectorDetails',
        },
    },
    { $unwind: '$userDetails' },
    { $unwind: '$sectorDetails' },
    {
        $project: {
            _id: 0,
            sectorId: '$sectorDetails.sectorId',
            sessions: {
                friend: {
                    _id: '$userDetails._id',
                    username: '$userDetails.username',
                    avatarUrl: '$userDetails.avatarUrl',
                    status: '$userDetails.status',
                },
                expiresAt: '$expiresAt',
            },
        },
    },
    {
        $group: {
            _id: '$sectorId',
            sessions: { $push: '$sessions' },
        },
    },
];

const apiDoc = {
    message: 'API pour récupérer les menus et restaurants du CROUS BFC',
    author: {
        name: 'Léo Maugeri',
        email: 'leomaugeri25@gmail.com',
    },
    version: '1.0.0',
    data: {
        static: [
            {
                name: 'Menus',
                description: 'Récupère les prochains menus d\'un restaurant (par défaut : RU Lumière)',
                method: 'GET',
                endpoint: '/menus?restaurantId=r135',
            },
            {
                name: 'Restaurants',
                description: 'Liste tous les restaurants CROUS synchronisés (id CROUS + nom + type...)',
                method: 'GET',
                endpoint: '/restaurants',
            },
            {
                name: 'Sync restaurants',
                description: 'Force la resynchronisation du catalogue depuis le flux CROUS (auto sinon, ~3 mois)',
                method: 'POST',
                endpoint: '/restaurants/sync',
                auth: true,
            },
        ],
    },
};

const getMenus = async (req: Request, res: Response) => {
    try {
        // Identifiant officiel CROUS ('r135'), optionnel : défaut = RU Lumière
        const restaurantId = typeof req.query.restaurantId === 'string' && req.query.restaurantId.trim().length > 0
            ? req.query.restaurantId.trim()
            : ru_lumiere_id;
        if (!/^r\d+$/i.test(restaurantId)) {
            return res.status(400).json({ error: 'Invalid restaurant ID format (attendu : rXXX)' });
        }

        // Cache par restaurant (1 jour) ; au miss, on repart du flux brut
        // partagé (rafraîchi au max toutes les heures) pour éviter de
        // requêter le service CROUS pour chaque restaurant.
        const cacheKey = `menus:${restaurantId}`;
        let menus: MenuResponse[] | undefined = menuCache.get(cacheKey);
        if (menus) {
            logger.info('Les menus sont en cache');
        } else {
            let menusByResto: Map<string, MenuResponse[]> | undefined = menuCache.get('menufeed');
            if (!menusByResto) {
                menusByResto = await fetchAllCrousMenus();
                menuCache.set('menufeed', menusByResto, RAW_FEED_TTL);
            }
            menus = menusByResto.get(restaurantId);
            if (!menus) {
                return res.status(404).json({ error: `Aucun menu trouvé pour le resto ${restaurantId}` });
            }
            menuCache.set(cacheKey, menus, MENU_CACHE_TTL);
        }

        // En prod : on ancre sur la vraie date du jour (filtre `>= today`).
        // En dev, si le flux ne contient aucune date future (fixture statique
        // hors-ligne), on ancre sur sa 1ère date pour garder une semaine exemple.
        const realToday = new Date().toISOString().split('T')[0];
        let today = realToday;
        let filtered = menus.filter((menu: MenuResponse) => menu.date >= today);
        if (!isProduction && filtered.length === 0 && menus.length > 0) {
            const fixtureStart = menus.map(m => m.date).sort((a, b) => a.localeCompare(b))[0];
            today = fixtureStart;
            filtered = menus.filter((menu: MenuResponse) => menu.date >= today);
        }

        // Filtre + comblement appliqués par requête (dépendent de `today`, donc non cachés)
        return res.json({ menus: fillClosedDays(filtered, today) });
    } catch (error) {
        logger.error('Erreur lors de la récupération des menus:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des menus' });
    }
};

const getSectors = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;

    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }

        // Accepte un ObjectId Mongo ou un identifiant CROUS ('r135')
        const restaurant = await findRestaurantByAnyId(restaurantId);
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }
        const sectors = await getSectorsFromRestaurant(restaurant._id);

        return res.json({ sectors });
    } catch (error) {
        logger.error('Erreur lors de la récupération des secteurs:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des secteurs' });
    }
};

const getRestaurants = async (req: Request, res: Response) => {
    try {
        const restaurants = await Restaurant.find()
            .select('restaurantId name address type zone')
            .limit(200)
            .sort({ name: 1 });
        if (!restaurants || restaurants.length === 0) {
            return res.status(404).json({ error: 'No restaurants found' });
        }
        return res.json({
            // `restaurantId` = identifiant officiel CROUS ('r135') : c'est lui
            // qui sert aux menus et à l'affichage ; `id` = ObjectId interne.
            restaurants: restaurants.map(r => ({
                id: r._id,
                restaurantId: r.restaurantId,
                name: r.name,
                ...(r.address ? { address: r.address } : {}),
                ...(r.type ? { type: r.type } : {}),
                ...(r.zone ? { zone: r.zone } : {}),
            })),
        });
    } catch (error) {
        logger.error('Erreur lors de la récupération des restaurants:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des restaurants' });
    }
};

const getSectorsSessions = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }

        const restaurant = await findRestaurantByAnyId(restaurantId, 'sectors -_id');
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }

        const userId = req.user.id;
        const user = await getUserById(userId, 'friends');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Conversion correcte des IDs d'amis en ObjectId
        const friendObjectIds = user.friends.map(id => new Types.ObjectId(id));

        const friendsInSectors = await SectorSession.aggregate(
            buildSectorSessionsPipeline(restaurant.sectors, friendObjectIds),
        );

        if (!friendsInSectors || friendsInSectors.length === 0) {
            logger.info('No friends found in sectors');
            return res.status(200).json({ message: 'No friends found in sectors' });
        }

        logger.info('Friends in sectors: %o', friendsInSectors);

        const formatted: friendsInSector = {};
        for (const item of friendsInSectors) {
            formatted[item._id] = item.sessions;
        }

        if (!formatted || Object.keys(formatted).length === 0) {
            return res.status(200).json({ message: 'No friends found in sectors' });
        }

        logger.info('Formatted friends in sectors: %o', formatted);

        return res.status(200).json(formatted);
    } catch (error) {
        logger.error('Error getting sectors with friends:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

// Renvoie TOUTES les sessions des secteurs du restaurant (pas seulement les amis).
// Comportement volontairement public à tout utilisateur authentifié : il sert à
// visualiser l'affluence globale du RU (cf. AUDIT.md, décision conservée).
const getAllSectorsSessions = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }

        const restaurant = await findRestaurantByAnyId(restaurantId, 'sectors -_id');
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }

        const allSessions = await SectorSession.aggregate(
            buildSectorSessionsPipeline(restaurant.sectors),
        );

        if (!allSessions || allSessions.length === 0) {
            logger.info('No sessions found in sectors');
            return res.status(200).json({ message: 'No sessions found in sectors' });
        }

        const formatted: friendsInSector = {};
        for (const item of allSessions) {
            formatted[item._id] = item.sessions;
        }

        if (!formatted || Object.keys(formatted).length === 0) {
            return res.status(200).json({ message: 'No sessions found in sectors' });
        }

        logger.info('All sessions in sectors: %o', formatted);
        return res.status(200).json(formatted);
    } catch (error) {
        logger.error('Error getting all sectors sessions:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

const getApiDoc = (_req: Request, res: Response) => {
    return res.json(apiDoc);
};

// Re-sync forcé du catalogue (sinon automatique, au plus souvent tous les
// 3 mois : voir syncRestaurantsFromCrous). Protégé par auth : déclenche un
// appel réseau vers le flux CROUS.
const syncRestaurants = async (_req: Request, res: Response) => {
    try {
        const result = await syncRestaurantsFromCrous(true);
        return res.json(result);
    } catch (error) {
        logger.error('Erreur lors du sync CROUS forcé:', error);
        return res.status(502).json({ error: 'Flux CROUS injoignable' });
    }
};

const getRestaurantInfo = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }
        // Accepte un ObjectId Mongo ou un identifiant CROUS ('r135')
        const restaurant = await findRestaurantByAnyId(restaurantId, 'name restaurantId address description type zone -_id');
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }
        return res.json({ restaurant });
    } catch (error) {
        logger.error('Erreur lors de la récupération des informations du restaurant:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des informations du restaurant' });
    }
};

const getRestaurantByOwnId = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }
        // Accepte un ObjectId Mongo ou un identifiant CROUS ('r135')
        const restaurant = await findRestaurantByAnyId(restaurantId, 'name restaurantId address description type zone -_id');
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }
        return res.json({ restaurant });
    } catch (error) {
        logger.error('Erreur lors de la récupération des informations du restaurant:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des informations du restaurant' });
    }
};

export { getMenus, getApiDoc, getSectors, getRestaurants, getSectorsSessions, getAllSectorsSessions, getRestaurantInfo, getRestaurantByOwnId, syncRestaurants };
