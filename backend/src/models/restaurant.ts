import { Schema, Document, Types, model } from 'mongoose';

interface IRestaurant extends Document {
    _id: Types.ObjectId;
    sectors: Types.ObjectId[];
    id: string;
    name: string;
    address: string;
    description: string;
}

const RestaurantSchema = new Schema({
    sectors: [{ type: Schema.Types.ObjectId, ref: 'Sector' }],
    id: { type: String, required: true },
    name: { type: String, required: true },
    address: { type: String, required: true },
    description: { type: String, required: true },

}, {
    timestamps: true,
});

const Restaurant = model<IRestaurant>('Restaurant', RestaurantSchema);

export default Restaurant;
export { IRestaurant };
