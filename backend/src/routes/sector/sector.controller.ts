import User from '../../models/user.js';
import logger from '../../utils/logger.js';
import { createSectorSession, findSectorById, findSectorSessionByUserId, findSectorSessionsForSector } from './sector.service.js';
import { Request, Response } from 'express';

const joinSector = async (req: Request, res: Response) => {
    const { sectorId, duration } = req.body;

    try {
        if (!sectorId || !duration) {
            logger.error('Missing required fields');
            return res.status(400).json({ error: 'Missing required fields' });
        }
        // // betveen 5 and 30 min
        // if (duration < 5 || duration > 30) {
        //     return res.status(400).json({ error: 'Duration must be between 5 and 30 minutes' });
        // }

        const user = await User.findById(req.user.id);
        if (!user) {
            logger.error('User not found');
            return res.status(404).json({ error: 'User not found' });
        }

        const existingSectorSession = await findSectorSessionByUserId(req.user.id);
        if (existingSectorSession) {
            return res.status(400).json({ error: 'User is already sitting at a sector' });
        }

        // Find the sector by ID
        const sector = await findSectorById(sectorId);
        if (!sector) {
            logger.error('Sector not found');
            return res.status(404).json({ error: 'Sector not found' });
        }

        const session = await createSectorSession(sectorId, user._id, duration);
        if (!session) {
            logger.error('Error creating sector session');
            return res.status(500).json({ error: 'Error creating sector session' });
        }

        return res.json({
            success: true,
            message: `Successfully sat in sector for ${duration} minutes`,
        });
    } catch (error) {
        logger.error('Erreur lors de la mise à jour du secteur:', error);
        return res.status(500).json({
            error: 'Erreur lors de la mise à jour du secteur',
            success: false,
        });
    }
};

const leaveSector = async (req: Request, res: Response) => {
    const { sectorId } = req.params;

    try {
        if (!sectorId) {
            return res.status(400).json({ error: 'Sector ID is required' });
        }

        // Find the sector by ID
        const sector = await findSectorById(sectorId);
        if (!sector) {
            return res.status(404).json({ error: 'Sector not found' });
        }

        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }
        const userId = user._id;

        const existingSectorSession = await findSectorSessionByUserId(userId);
        if (!existingSectorSession) {
            return res.status(400).json({ error: 'User is not sitting at any sector' });
        }

        await existingSectorSession.deleteOne();

        return res.status(200).json({ message: 'You have left the sector' });
    } catch (error) {
        logger.error('Error leaving sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

const getFriendsInSector = async (req: Request, res: Response) => {
    const { sectorId } = req.params;

    try {
        if (!sectorId) {
            return res.status(400).json({ error: 'Sector ID is required' });
        }
        // Find the user making the request
        const user = await User.findById(req.user.id).select('friends');
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        const sectorSessions = await findSectorSessionsForSector(sectorId, true);
        if (!sectorSessions || sectorSessions.length === 0) {
            return res.status(200).json({ message: 'No users found in this sector' });
        }

        // const friendsInSector = sectorsSessions.filter((session) => {
        //     const friend = user.friends.find(friend => friend.id.toString() === session.user.toString());
        //     return friend !== undefined;
        // });

        const friendsInSector = sectorSessions.filter(session =>
            user.friends.some(friendId => friendId.toString() === session.user.toString()),
        );
        if (friendsInSector.length === 0) {
            return res.status(200).json({ error: 'No friends found in this sector' });
        }

        return res.status(200).json({ friendsInSector: friendsInSector });
    } catch (error) {
        logger.error('Error getting friends in sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

export { joinSector, leaveSector, getFriendsInSector };
