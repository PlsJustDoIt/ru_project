import mongoose from 'mongoose';

const RefreshTokenSchema = new mongoose.Schema({
    token: { type: String, required: true },
    userId: { type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true },
    expires: { type: Date, required: true },
}, { timestamps: true });

RefreshTokenSchema.index({ createdAt: 1 }, { expireAfterSeconds: 24 * 3600 * 7 }); // Expire après une semaine

export default mongoose.model('RefreshToken', RefreshTokenSchema);
