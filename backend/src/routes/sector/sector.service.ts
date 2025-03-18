import { ObjectId } from 'mongoose';
import Sector, { ISector } from '../../models/sector.js';

const createSector = async (position: { x: number; y: number }, size: { width: number; height: number }, participants?: ObjectId[], name?: string, color?: string): Promise<ISector> => {
    const sector = new Sector({ name, position, size, color, participants });
    return await sector.save();
};

const findSector = async (name: string): Promise<ISector | null> => {
    return await Sector.findOne({ name: name });
};

const findSectorById = async (id: string | ObjectId): Promise<ISector | null> => {
    return await Sector.findById(id);
};

const deleteSector = async (name: string): Promise<void> => {
    await Sector.deleteOne({ name: name });
};

export { createSector, findSector, findSectorById, deleteSector };
