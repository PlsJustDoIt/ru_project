import { Schema, Document, Types, model } from 'mongoose';

interface IRoom extends Document {
    name: string;
    owner: Types.ObjectId;
    _id: Types.ObjectId;
}

const RoomSchema: Schema = new Schema({
    name: { type: String, required: true },
    owner: { type: Types.ObjectId, ref: 'User', required: true },
});

const Room = model<IRoom>('Room', RoomSchema);

export default Room;
