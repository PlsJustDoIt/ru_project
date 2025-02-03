import { Schema, model } from 'mongoose';

const RefreshTokenSchema = new Schema({
    token: { type: String, required: true },
    userId: { type: Schema.Types.ObjectId,
        ref: 'User',
        required: true },
    expires: { type: Date, required: true },
}, { timestamps: true });

RefreshTokenSchema.index({ createdAt: 1 }, { expireAfterSeconds: 24 * 3600 * 7 }); // Expire après une semaine

export default model('RefreshToken', RefreshTokenSchema);
