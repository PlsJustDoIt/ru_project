import Sector from '../../models/sector.js';
import User from '../../models/user.js';
import logger from '../../utils/logger.js';
import { findSectorById } from './sector.service.js';
import { Request, Response } from 'express';

const joinSector = async (req: Request, res: Response) => {
    const { sectorId, durationMin } = req.body;

    try {
        const user = await User.findById(req.user.id);
        if (!user) {
            logger.error('User not found');
            return res.status(404).json({ error: 'User not found' });
        }
        if (!sectorId || !durationMin) {
            logger.error('Missing required fields');
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
