import User from '../../models/user.js';
import logger from '../../services/logger.js';
import { findSectorById } from './sector.service.js';
import { Request, Response } from 'express';

const joinSector = async (req: Request, res: Response) => {
    const { sectorId } = req.params;

    try {
        const sector = await findSectorById(sectorId);
        if (!sector) return res.status(404).json({ error: 'Sector not found' });

        if (!sector.participants.includes(req.user.id)) {
            sector.participants.push(req.user.id);
            await sector.save();
            return res.status(200).json({ message: 'You have joined the sector' });
        }

        return res.status(409).json({ message: 'You are already a participant of this sector' });
    } catch (error) {
        logger.error('Error joining sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

const leaveSector = async (req: Request, res: Response) => {
    const { sectorId } = req.params;

    try {
        const sector = await findSectorById(sectorId);
        if (!sector) return res.status(404).json({ error: 'Sector not found' });

        const index = sector.participants.indexOf(req.user.id);
        if (index > -1) {
            sector.participants.splice(index, 1);
            await sector.save();
            return res.status(200).json({ message: 'You have left the sector' });
        }

        return res.status(404).json({ message: 'You are not a participant of this sector' });
    } catch (error) {
        logger.error('Error joining sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

const getFriendsInSector = async (req: Request, res: Response) => {
    const { sectorId } = req.params;

    try {
        const sector = await findSectorById(sectorId);
        if (!sector) return res.status(404).json({ error: 'Sector not found' });

        const friendsInSector = sector.participants.filter(participant => req.user.friends.includes(participant));

        const populatedFriends = await User.find({ _id: { $in: friendsInSector } })
            .select('-password -__v'); // Exclure les champs sensibles
        return res.status(200).json({ friendsInSector: populatedFriends });
    } catch (error) {
        logger.error('Error getting friends in sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

export { joinSector, leaveSector, getFriendsInSector };
