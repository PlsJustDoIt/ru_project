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
        // Validate sectorId
        if (!sectorId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({ error: 'Invalid sector ID' });
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
        const userId = user?._id;

        // Check if the user is a participant in the sector
        const participantIndex = sector.participants.findIndex(
            participant => participant.userId.toString() == userId.toString(),
        );

        if (participantIndex === -1) {
            return res.status(400).json({ error: 'You are not a participant of this sector' });
        }

        // Remove the user from the participants array
        sector.participants.splice(participantIndex, 1);
        await sector.save();

        return res.status(200).json({ message: 'You have left the sector' });
    } catch (error) {
        logger.error('Error leaving sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

const getFriendsInSector = async (req: Request, res: Response) => {
    const { sectorId } = req.params;

    try {
        // Find the user making the request
        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Find the sector by ID
        const sector = await findSectorById(sectorId);
        if (!sector) {
            return res.status(404).json({ error: 'Sector not found' });
        }

        // Filter participants who are friends of the user
        const friendsInSector = sector.participants.filter(participant =>
            user.friends.some(friendId => friendId.toString() === participant.userId.toString()),
        );

        // Populate the friends' details
        const populatedFriends = await User.find({ _id: { $in: friendsInSector.map(p => p.userId) } })
            .select('-password -__v'); // Exclude sensitive fields

        return res.status(200).json({ friendsInSector: populatedFriends });
    } catch (error) {
        logger.error('Error getting friends in sector:', error);
        return res.status(500).json({ error: 'Server error' });
    }
};

export { joinSector, leaveSector, getFriendsInSector };
