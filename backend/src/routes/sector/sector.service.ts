import { Types } from 'mongoose';
import Sector, { ISector } from '../../models/sector.js';
import SectorSession, { ISectorSession } from '../../models/sectorSession.js';

/**
 * Creates a new sector with the given parameters.
 * @param position The position of the sector.
 * @param size The size of the sector.
 * @param participants The participants of the sector.
 * @param name The name of the sector.
 * @param color The color of the sector.
 * @returns A promise that resolves with the created sector.
 */
const createSector = async (position: { x: number; y: number }, size: { width: number; height: number }, restaurant: Types.ObjectId, name?: string, color?: string): Promise<ISector> => {
    const sector = new Sector({ name, position, size, color, restaurant });
    return await sector.save();
};

const findSectorById = async (id: string | Types.ObjectId): Promise<ISector | null> => {
    return await Sector.findById(id);
};

const deleteSector = async (name: string): Promise<void> => {
    await Sector.deleteOne({ name: name });
};

const createSectorSession = async (sectorId: string | Types.ObjectId, userId: string | Types.ObjectId, duration: number): Promise<ISectorSession> => {
    const expiresAt = new Date(Date.now() + duration * 60 * 1000);
    const remainingTime = Math.floor((expiresAt.getTime() - Date.now()) / 1000);
    console.log('Remaining time in seconds:', remainingTime);
    const session = new SectorSession({ sector: sectorId, user: userId, expiresAt });
    return await session.save();
};

const findSectorSessionByUserId = async (userId: string | Types.ObjectId): Promise<ISectorSession | null> => {
    return await SectorSession.findOne({ user: userId });
};

/**
 * @async
 * @function findSectorSessionsForSector
 * @description Finds sector sessions for a specific sector.
 * @param {string | Types.ObjectId} sectorId - The ID of the sector to find sessions for.
 * @param {boolean} populate - Whether to populate the 'user' field with 'username', 'avatarUrl', and 'status'.
 * @returns {Promise<ISectorSession[]>} - A promise that resolves with an array of sector sessions.
 */
const findSectorSessionsForSector = async (sectorId: string | Types.ObjectId, populate: boolean): Promise<ISectorSession[]> => {
    if (populate) {
        return await SectorSession.find({ sector: sectorId }).populate('user', 'username avatarUrl status');
    } else {
        return await SectorSession.find({ sector: sectorId });
    }
};
const deleteSectorSession = async (sectorId: string | Types.ObjectId, userId: string | Types.ObjectId): Promise<void> => {
    await SectorSession.deleteOne({ sector: sectorId, user: userId });
};
const deleteSectorSessionsForSector = async (sectorId: string | Types.ObjectId): Promise<void> => {
    await SectorSession.deleteMany({ sector: sectorId });
};

export { createSector, findSectorById, deleteSector, createSectorSession, findSectorSessionByUserId, findSectorSessionsForSector, deleteSectorSession, deleteSectorSessionsForSector };
