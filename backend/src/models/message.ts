import { Schema, Types, model } from 'mongoose';

interface IMessage {
    content: string;
    created_timestamp: Date;
    user: Types.ObjectId;
    room: Types.ObjectId;
}

const messageSchema = new Schema<IMessage>({
    content: { type: String, required: true },
    user: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    room: { type: Schema.Types.ObjectId, required: true, ref: 'Room' },
}, { timestamps: true });

const Message = model<IMessage>('Message', messageSchema);

export default Message;
export { IMessage };
