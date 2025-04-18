import { Schema, Document, Types, model } from 'mongoose';

interface ISectorSession extends Document {
    _id: Types.ObjectId;
    user: Types.ObjectId;
    sector: Types.ObjectId;
    expiresAt: Date;
}

const SectorSessionSchema = new Schema({
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    sector: { type: Schema.Types.ObjectId, ref: 'Sector', required: true },
    expiresAt: { type: Date, required: true },
});

// Maintenant l'index doit aussi refléter ce changement de nommage
SectorSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
SectorSessionSchema.index({ user: 1 }, { unique: true });

const SectorSession = model<ISectorSession>('SectorSession', SectorSessionSchema);

export default SectorSession;
export { ISectorSession };
