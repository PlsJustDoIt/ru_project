import { Request, Response } from 'express';
import { MenuResponse } from '../../interfaces/menu.js';
import logger from '../../utils/logger.js';
import { fetchMenusFromExternalAPI, findRestaurant } from './ru.service.js';
import NodeCache from 'node-cache';
import Sector from '../../models/sector.js';
import User from '../../models/user.js';
import Restaurant from '../../models/restaurant.js';

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
    const ruId = req.params.ruId;

    try {
        // Find the restaurant by ID
        const ru = await findRestaurant(ruId);
        if (!ru) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }

        // Check if the restaurant has sectors
        if (ru.sectors.length === 0) {
            return res.status(404).json({ error: 'No sectors found' });
        }

        // Fetch the sectors with populated participants
        const sectors = await Sector.find({ _id: { $in: ru.sectors } })
            .populate({
                path: 'participants.userId',
                select: 'username avatarUrl status', // Only include necessary fields
            });

        // Get the current user
        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Use the user's friends array directly to filter participants
        const friendIds = user.friends.map(friendId => friendId.toString()); // Convert ObjectIds to strings
        sectors.forEach((sector) => {
            sector.participants = sector.participants.filter(participant =>
                friendIds.includes(participant.userId._id.toString()),
            );
        });

        return res.json({ sectors });
    } catch (error) {
        logger.error('Erreur lors de la récupération des secteurs:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des secteurs' });
    }
};

const sitAtSector = async (req: Request, res: Response) => {
    const { sectorId, durationMin } = req.body;

    try {
        const user = await User.findById(req.user.id);
        if (!user) {
            logger.error('User not found');
            return res.status(404).json({ error: 'User not found' });
        }
        if (!sectorId || !durationMin) {
            return res.status(400).json({ error: 'Missing required fields' });
        }
        // betveen 5 and 30 min
        if (durationMin < 5 || durationMin > 30) {
            return res.status(400).json({ error: 'Duration must be between 5 and 30 minutes' });
        }
        // Check if the user is already sitting at a sector
        const existingSector = await Sector.findOne({
            'participants.userId': user._id,
        });
        if (existingSector) {
            return res.status(400).json({ error: 'User is already sitting at a sector' });
        }

        // Find the sector by ID
        const sector = await Sector.findById(sectorId);
        if (!sector) {
            logger.error('Sector not found');
            return res.status(404).json({ error: 'Sector not found' });
        }

        // Check if the user is already a participant in the sector
        const existingParticipant = sector.participants.find(participant =>
            participant.userId.toString() === user._id.toString(),
        );

        if (existingParticipant) {
            return res.status(400).json({ error: 'User is already sitting at this sector' });
        }

        // Add the user to the sector's participants with duration
        sector.participants.push({
            userId: user._id,
            satAt: new Date(),
            duration: durationMin,
        });

        await sector.save();

        return res.json({
            success: true,
            message: `Successfully sat in sector for ${durationMin} minutes`,
        });
    } catch (error) {
        logger.error('Erreur lors de la mise à jour du secteur:', error);
        return res.status(500).json({
            error: 'Erreur lors de la mise à jour du secteur',
            success: false,
        });
    }
};

const getRestaurants = async (req: Request, res: Response) => {
    try {
        const restaurants = await Restaurant.find().select('name restaurantId').limit(10);
        if (!restaurants || restaurants.length === 0) {
            return res.status(404).json({ error: 'No restaurants found' });
        }
        return res.json({ restaurants });
    } catch (error) {
        logger.error('Erreur lors de la récupération des restaurants:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des restaurants' });
    }
};

const getApiDoc = (res: Response) => {
    return res.json(apiDoc);
};

export { getMenus, getApiDoc, getSectors, sitAtSector, getRestaurants };
