import { Schema, Document, Types, model, Model } from 'mongoose';

interface IParticipant {
    userId: Types.ObjectId;
    satAt: Date;
    duration: number; // in minutes
}

interface ISector extends Document {
    _id: Types.ObjectId;
    participants: IParticipant[];
    position: { x: number; y: number };
    size: { width: number; height: number };
    name?: string;
}

const ParticipantSchema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    satAt: { type: Date, required: true, default: Date.now },
    duration: { type: Number, required: true }, // in minutes
});

ParticipantSchema.index({ duration: 1, satAt: 1 });

/*

const ParticipantSchema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    satAt: { type: Date, required: true, default: Date.now },
    duration: { type: Number, required: true }, // in minutes
    expiresAt: { type: Date, required: true }, // Automatically calculated expiration time
});

// Pre-save hook to calculate `expiresAt`
ParticipantSchema.pre('save', function (next) {
    const participant = this as any; // Cast to access fields
    participant.expiresAt = new Date(participant.satAt.getTime() + participant.duration * 60000); // satAt + duration in ms
    next();
});

// Add TTL index on `expiresAt`
ParticipantSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

*/
interface ISectorModel extends Model<ISector> {
    cleanupExpiredParticipants: () => Promise<void>;
}

const SectorSchema = new Schema(
    {
        name: { type: String },
        participants: [ParticipantSchema],
        position: {
            x: { type: Number, required: true },
            y: { type: Number, required: true },
        },
        size: {
            width: { type: Number, required: true },
            height: { type: Number, required: true },
        },
    },
    {
        timestamps: true,
    },
);

// Add an index for efficient queries
SectorSchema.index({ 'participants.userId': 1 }, { unique: true });

// Static method to clean up expired participants
SectorSchema.statics.cleanupExpiredParticipants = async function () {
    const now = new Date();
    try {
        // Utiliser updateMany avec $pull pour supprimer les participants expirés en une seule opération
        const result = await this.updateMany(
            {}, // Tous les secteurs
            {
                $pull: {
                    participants: {
                        $expr: {
                            $lt: [
                                { $add: ['$satAt', { $multiply: ['$duration', 60000] }] },
                                now,
                            ],
                        },
                    },
                },
            },
        );

        console.log(`Nettoyage terminé. Documents modifiés: ${result.modifiedCount}`);
    } catch (error) {
        console.error('Erreur lors du nettoyage des participants expirés:', error);
    }
};

// Pre-save hook to check for duplicate participants
SectorSchema.pre('save', function (next) {
    next();
});

const Sector = model<ISector, ISectorModel>('Sector', SectorSchema);

// Cleanup job to remove expired participants every 5 minutes
const cleanupJob = setInterval(async () => {
    try {
        await Sector.cleanupExpiredParticipants();
    } catch (error) {
        console.error('Error during scheduled cleanup:', error);
    }
}, 1 * 60 * 1000); // Run every 5 minutes

// Graceful shutdown for cleanup job
const shutdownCleanupJob = () => {
    clearInterval(cleanupJob);
    console.log('Cleanup job stopped.');
    process.exit();
};

process.on('SIGINT', shutdownCleanupJob);
process.on('SIGTERM', shutdownCleanupJob);

export default Sector;
export { ISector, IParticipant, ISectorModel };
