import { Schema, Document, Types, model, ObjectId } from 'mongoose';

interface ISector extends Document {
    _id: Types.ObjectId;
    participants: ObjectId[];
    position: { x: number; y: number };
    size: { width: number; height: number };
    color?: string;
    name?: string;
}

const SectorSchema = new Schema({

    name: { type: String },
    participants: [{ type: Schema.Types.ObjectId, ref: 'User', required: true, default: [] }],
    position: {
        x: { type: Number, required: true },
        y: { type: Number, required: true },
    },
    size: {
        width: { type: Number, required: true },
        height: { type: Number, required: true },
    },
    color: { type: String, default: '#FFFFFF' },

}, {
    timestamps: true,
});

SectorSchema.index({ participants: 1, name: 1 }, { unique: true });

const Sector = model<ISector>('Room', SectorSchema);

export default Sector;
export { ISector };
