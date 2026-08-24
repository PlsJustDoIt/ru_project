import { Schema, Document, Types, model } from 'mongoose';

interface IRestaurant extends Document {
    _id: Types.ObjectId;
    sectors: Types.ObjectId[];
    restaurantId: string; // identifiant officiel CROUS, ex. 'r135'
    name: string;
    address: string;
    description: string;
    type?: string; // 'Restaurant', 'Cafétéria', 'Foodtruck'...
    zone?: string; // ville / zone CROUS, ex. 'Besançon'
    createdAt?: Date; // via timestamps: true
    updatedAt?: Date; // = dernier sync CROUS du document
}

const RestaurantSchema = new Schema({
    sectors: [{ type: Schema.Types.ObjectId, ref: 'Sector' }],
    restaurantId: { type: String, required: true, unique: true }, // id CROUS, ex. 'r135'
    name: { type: String, required: true },
    address: { type: String, required: true },
    description: { type: String, required: true },
    type: { type: String },
    zone: { type: String },

}, {
    timestamps: true,
});

const Restaurant = model<IRestaurant>('Restaurant', RestaurantSchema);

export default Restaurant;
export { IRestaurant };
