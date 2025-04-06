import { Schema, Document, Types, model } from 'mongoose';

interface IRoom extends Document {
    participants?: Types.ObjectId[];
    _id: Types.ObjectId;
    name: string;
}

const RoomSchema: Schema = new Schema({
    participants: [{
        type: Schema.Types.ObjectId,
        ref: 'User',
    }],
    name: { type: String, required: true },

}, {
    timestamps: true,
});

RoomSchema.index({ participants: 1, name: 1 }, { unique: true });

const Room = model<IRoom>('Room', RoomSchema);

export default Room;
export { IRoom };
