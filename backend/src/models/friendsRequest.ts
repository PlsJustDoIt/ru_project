import { Schema, Types, model } from 'mongoose';

type Status = 'pending' | 'accepted' | 'rejected';

interface IFriendRequest {
    _id: Types.ObjectId;
    sender: Types.ObjectId;
    receiver: Types.ObjectId;
    status: Status;
    createdAt: Date;
}

const friendRequestSchema = new Schema<IFriendRequest>({
    sender: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    receiver: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    status: { type: String, enum: ['pending', 'accepted', 'rejected'], default: 'pending' },
}, { timestamps: true });

const FriendRequest = model<IFriendRequest>('FriendRequest', friendRequestSchema);

export default FriendRequest;
export { IFriendRequest, Status };
