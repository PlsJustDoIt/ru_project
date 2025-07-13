import { Schema, model } from 'mongoose';

interface IRefreshToken extends Document {
    _id: Schema.Types.ObjectId;
    token: string;
    userId: Schema.Types.ObjectId;
    expires: Date;
    createdAt: Date;
    updatedAt: Date;
}

const RefreshTokenSchema = new Schema({
    token: { type: String, required: true },
    userId: { type: Schema.Types.ObjectId,
        ref: 'User',
        required: true },
    expires: { type: Date, required: true },
}, { timestamps: true });

RefreshTokenSchema.index({ expires: 1 }, { expireAfterSeconds: 0 });

export default model<IRefreshToken>('RefreshToken', RefreshTokenSchema);
