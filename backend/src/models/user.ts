import { CallbackError, Schema, Types, model } from 'mongoose';
import { genSalt, hash } from 'bcrypt';

type Status = 'en ligne' | 'au ru' | 'absent';
interface IUser extends Document {
    username: string;
    password: string;
    status: Status;
    friends: Types.ObjectId[];
    avatarUrl: string;
    _id: Types.ObjectId;
}

const UserSchema = new Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    status: { type: String, enum: ['en ligne', 'au ru', 'absent'], default: 'absent' },
    friends: [{ type: Schema.Types.ObjectId, ref: 'User' }],
    avatarUrl: { type: String, default: 'uploads/avatar/default.png' },
}, { timestamps: true });

UserSchema.pre('save', async function (next): Promise<void> {
    try {
        if (!this.isModified('password')) return next();
        const salt = await genSalt(10);
        this.password = await hash(this.password, salt);
        next();
    } catch (error: unknown) {
        next(error as CallbackError);
    }
});

const User = model<IUser>('User', UserSchema);

export default User;
export { IUser, Status };
