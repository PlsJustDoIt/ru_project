
import {CallbackError, Schema, model} from 'mongoose';
import {genSalt, hash} from 'bcrypt';

const UserSchema = new Schema({
    username: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    status: { type: String, default: 'Inactif' },
    friends: [{ type: Schema.Types.ObjectId, ref: 'User' }],
});

UserSchema.pre('save', async function(next): Promise<void> {
    try {
        if (!this.isModified('password')) return next();
        const salt = await genSalt(10);
        this.password = await hash(this.password, salt);
        next();
    } catch (error : unknown) {
        next(error as CallbackError);
    }
});

export default model('User', UserSchema);
