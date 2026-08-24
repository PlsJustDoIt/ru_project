import { ObjectId } from 'mongoose';
export interface restaurant {
    sectors?: ObjectId[];
    restaurantId: string;
    name: string;
    address: string;
    description: string;
    type?: string;
    zone?: string;
}

// Resto tel que décrit dans le flux CROUS (resto.xml)
export interface crousResto {
    restaurantId: string;
    name: string;
    address: string;
    description: string;
    type?: string;
    zone?: string;
}
