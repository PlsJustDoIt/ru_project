import { Schema, Types, model } from 'mongoose';

type Status = 'pending' | 'accepted' | 'rejected';

interface IFriendsRequest {
    _id: Types.ObjectId;
    sender: Types.ObjectId;
    receiver: Types.ObjectId;
    status: Status;
    createdAt: Date;
}

const FriendsRequestSchema = new Schema<IFriendsRequest>({
    sender: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    receiver: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    status: { type: String, enum: ['pending', 'accepted', 'rejected'], default: 'pending' },
}, { timestamps: true });

const FriendsRequest = model<IFriendsRequest>('FriendsRequest', FriendsRequestSchema);

export default FriendsRequest;
export { IFriendsRequest, Status };
