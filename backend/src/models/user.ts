import { CallbackError, Schema, Types, model } from 'mongoose';
import { genSalt, hash } from 'bcrypt';

interface IUser extends Document {
    username: string;
    password: string;
    status: string;
    friends: IUser[];
    avatarUrl: string;
    _id: Types.ObjectId;
}

const UserSchema = new Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    status: { type: String, default: 'Inactif' },
    friends: [{ type: Schema.Types.ObjectId, ref: 'User' }],
    avatarUrl: { type: String, default: 'uploads/avatar/default.png' },
});

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

export default model('User', UserSchema);
export { IUser };
