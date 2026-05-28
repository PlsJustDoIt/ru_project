import { Request, Response } from 'express';
import { MenuResponse } from '../../interfaces/menu.js';
import logger from '../../utils/logger.js';
import { fetchMenusFromExternalAPI, findRestaurant, findRestaurantById, getSectorsFromRestaurant } from './ru.service.js';
import NodeCache from 'node-cache';
import Restaurant from '../../models/restaurant.js';
import { getUserById } from '../user/user.service.js';
import SectorSession from '../../models/sectorSession.js';
import { Types } from 'mongoose';
import friendsInSector from '../../interfaces/friendsInSector.js';

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

const getMenus = async (req: Request, res: Response) => {
    try {
        // On vérifie si les menus sont en cache
        const cachedMenus: MenuResponse[] | undefined = cache.get('menus');
        if (cachedMenus) {
            logger.info('Les menus sont en cache');
            const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format
            const filteredMenus = cachedMenus.filter((menu: MenuResponse) => menu.date >= today);
            return res.json({ menus: filteredMenus });
        }

        // Si les menus ne sont pas en cache, on les récupère de l'API externe
        const menus = await fetchMenusFromExternalAPI();

        // On met les menus en cache pour une semaine
        cache.set('menus', menus);
        return res.json({ menus: menus });
    } catch (error) {
        console.error('Erreur lors de la récupération des menus:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des menus' });
    }
};

const getSectors = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;

    try {
        if (!restaurantId || !Types.ObjectId.isValid(restaurantId)) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }

        const sectors = await getSectorsFromRestaurant(new Types.ObjectId(restaurantId));

        return res.json({ sectors });
    } catch (error) {
        logger.error('Erreur lors de la récupération des secteurs:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des secteurs' });
    }
};

const getRestaurants = async (req: Request, res: Response) => {
    try {
        const restaurants = await Restaurant.find().select('name restaurantId -_id').limit(10);
        if (!restaurants || restaurants.length === 0) {
            return res.status(404).json({ error: 'No restaurants found' });
        }
        return res.json({ restaurants });
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

        const restaurant = await findRestaurant(restaurantId, 'sectors -_id');
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

        const tmp_sectorsSessions = await SectorSession.find({}).populate('user', 'username avatarUrl status -_id');

        const friendsInSectors = await SectorSession.aggregate([
            {
                $match: {
                    user: { $in: friendObjectIds },
                    sector: { $in: restaurant.sectors },
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
                    // sector: { $first: '$sectorDetails' }, // Facultatif si tu veux encore les infos du secteur
                },
            },
        ]);

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

// Return ALL sessions in restaurant sectors, not only friends
const getAllSectorsSessions = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }

        const restaurant = await findRestaurant(restaurantId, 'sectors -_id');
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }

        const allSessions = await SectorSession.aggregate([
            {
                $match: {
                    sector: { $in: restaurant.sectors },
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
        ]);

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

const getRestaurantInfo = async (req: Request, res: Response) => {
    const restaurantId = req.params.restaurantId as string;
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }
        const restaurant = await findRestaurant(restaurantId, 'name restaurantId address description -_id');
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
    if (!Types.ObjectId.isValid(restaurantId)) {
        return res.status(400).json({ error: 'Invalid restaurant ID format' });
    }
    try {
        if (!restaurantId) {
            return res.status(400).json({ error: 'Restaurant ID is required' });
        }
        const restaurant = await findRestaurantById(new Types.ObjectId(restaurantId), 'name restaurantId address description -_id');
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }
        return res.json({ restaurant });
    } catch (error) {
        logger.error('Erreur lors de la récupération des informations du restaurant:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des informations du restaurant' });
    }
};

export { getMenus, getApiDoc, getSectors, getRestaurants, getSectorsSessions, getAllSectorsSessions, getRestaurantInfo, getRestaurantByOwnId };
