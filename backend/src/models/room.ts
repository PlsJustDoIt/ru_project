import { Schema, Document, Types, model } from 'mongoose';
// Assuming you have a User model

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
// Room.create({ name: 'chat room', owner: await User.findOne({ username: 'admin' }) })
//     .then(room => console.log('Default room created:', room))
//     .catch(err => console.error('Error creating default room:', err));

export default Room;
