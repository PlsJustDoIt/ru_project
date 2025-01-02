import { Schema, Document, Types, model } from 'mongoose';
// Assuming you have a User model

interface IRoom extends Document {
    participants?: Types.ObjectId[];
    _id: Types.ObjectId;
    name: string;
}

const RoomSchema: Schema = new Schema({
    participants: [{
        type: Schema.Types.ObjectId,
        ref: 'User',
    }],
    name: { type: String, required: true },

}, {
    timestamps: true,
});

RoomSchema.index({ participants: 1, name: 1 }, { unique: true });

const Room = model<IRoom>('Room', RoomSchema);

const generatePrivateRoomName = (user1Id: string, user2Id: string) => {
    return [user1Id, user2Id].sort().join('_');
};

// Fonction pour obtenir ou créer une room privée
async function getOrCreatePrivateRoom(user1Id: Types.ObjectId, user2Id: Types.ObjectId) {
    // Chercher une room existante avec exactement ces deux participants
    const existingRoom = await Room.findOne({
        participants: {
            $all: [user1Id, user2Id],
            $size: 2,
        },
    });

    if (existingRoom) {
        return existingRoom;
    }

    // Créer une nouvelle room si elle n'existe pas
    return await Room.create({
        participants: [user1Id, user2Id],
    });
}

// Fonction utilitaire pour trouver toutes les rooms privées d'un utilisateur
async function getUserRooms(userId: Types.ObjectId) {
    return await Room.find({
        participants: userId,
    }).populate('participants', 'username avatarUrl status');
}

export default Room;
export { IRoom, getOrCreatePrivateRoom, getUserRooms, generatePrivateRoomName };
