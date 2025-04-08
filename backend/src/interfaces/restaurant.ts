import { ObjectId } from 'mongoose';
export interface restaurant {
    sectors: ObjectId[];
    restaurantId: string;
    name: string;
    address: string;
    description: string;
}
