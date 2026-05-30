import { Schema, Types, model } from 'mongoose';

interface IMessage {
    content: string;
    audioUrl?: string;
    duration?: number;
    createdAt: Date;
    updatedAt: Date;
    user: Types.ObjectId | { username: string };
    room: Types.ObjectId;
    _id: Types.ObjectId;
}

const MessageSchema = new Schema<IMessage>({
    // content non requis : un message vocal porte audioUrl à la place.
    content: { type: String, default: '' },
    audioUrl: { type: String },
    duration: { type: Number },
    user: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    room: { type: Schema.Types.ObjectId, required: true, ref: 'Room' },
}, { timestamps: true });

const Message = model<IMessage>('Message', MessageSchema);

export default Message;
export { IMessage };
