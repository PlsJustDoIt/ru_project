import { Request, Response } from 'express';
import { MenuResponse } from '../../interfaces/menu.js';
import logger from '../../utils/logger.js';
import { fetchMenusFromExternalAPI, findRestaurant } from './ru.service.js';
import NodeCache from 'node-cache';
import Sector from '../../models/sector.js';

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

        //         // // Fetch the sectors with populated participants
        // const sectors = await Sector.find({ _id: { $in: ru.sectors } })
        //     .populate({
        //         path: 'participants.userId',
        //         select: 'username avatarUrl status', // Only include necessary fields
        //     });

        // Fetch the sectors with populated participants with only the userId
        // const sectors = await Sector.find({ _id: { $in: ru.sectors } })
        //     .populate({
        //         path: 'participants.userId',
        //         select: 'username avatarUrl status', // Only include necessary fields
        //     });

        // Fetch the sectors with populated participants with only the userId
        const sectors = await Sector.find({ _id: { $in: ru.sectors } })
            .populate({
                path: 'participants.userId',
                select: '_id', // Only fetch the userId
            });

        // Transform the participants field to an array of userId
        const transformedSectors = sectors.map(sector => ({
            _id: sector._id,
            name: sector.name,
            position: sector.position,
            size: sector.size,
            participants: sector.participants.map(participant => participant.userId._id),
        }));

        return res.json({ sectors: transformedSectors });
    } catch (error) {
        logger.error('Erreur lors de la récupération des secteurs:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des secteurs' });
    }
};

const getApiDoc = (res: Response) => {
    return res.json(apiDoc);
};

export { getMenus, getApiDoc, getSectors };
