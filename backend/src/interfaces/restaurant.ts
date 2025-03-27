import { ObjectId } from 'mongoose';
export interface restaurant {
    sectors: ObjectId[];
    id: string;
    name: string;
    address: string;
    description: string;
}
