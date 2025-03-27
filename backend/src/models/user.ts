import { CallbackError, Schema, Types, model } from 'mongoose';
import { genSalt, hash } from 'bcrypt';

type Status = 'en ligne' | 'au ru' | 'absent';
type role = 'user' | 'admin' | 'moderator';
interface IUser extends Document {
    username: string;
    password: string;
    status: Status;
    friends: Types.ObjectId[];
    avatarUrl: string;
    _id: Types.ObjectId;
    role: role;
}

interface baseUser {
    username: string;
    password: string;
    friends: Types.ObjectId[];
    status?: Status;
    avatarUrl?: string;
    role?: role;
}

const UserSchema = new Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    status: { type: String, enum: ['en ligne', 'au ru', 'absent'], default: 'absent' },
    friends: [{ type: Schema.Types.ObjectId, ref: 'User' }],
    avatarUrl: { type: String, default: 'uploads/avatar/default.png' },
    role: { type: String, enum: ['user', 'admin', 'moderator'], default: 'user' },
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

const createUser = async (user: baseUser) => {
    try {
        return await User.create(user);
    } catch (error: unknown) {
        throw new Error(error as string);
    }
};

const generateUser = (username: string, password: string): baseUser => {
    return {
        username,
        password,
        friends: [],
    };
};

export default User;
export { IUser, Status, createUser, generateUser };
