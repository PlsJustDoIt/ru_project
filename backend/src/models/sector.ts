import { Schema, Document, Types, model } from 'mongoose';

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
    color?: string;
    name?: string;
}

const ParticipantSchema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    satAt: { type: Date, required: true, default: Date.now },
    duration: { type: Number, required: true }, // in minutes
});

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
        color: { type: String, default: '#00FF00' }, // Default color is green
    },
    {
        timestamps: true,
    },
);

// Add an index for efficient queries
SectorSchema.index({ 'participants.userId': 1, 'name': 1 }, { unique: true });

// Static method to clean up expired participants
SectorSchema.statics.cleanupExpiredParticipants = async function () {
    const now = new Date();
    try {
        // Find all sectors with expired participants
        const sectors = await this.find({
            'participants.satAt': { $exists: true },
        });

        // Iterate through each sector and remove expired participants
        for (const sector of sectors) {
            const updatedParticipants = sector.participants.filter((participant: IParticipant) => {
                const expirationTime = new Date(participant.satAt.getTime() + participant.duration * 60000); // satAt + duration in ms
                return expirationTime > now; // Keep participants who haven't expired
            });

            // Update the sector with the filtered participants
            sector.participants = updatedParticipants;
            await sector.save();
        }

        console.log(`Cleaned up expired participants.`);
    } catch (error) {
        console.error('Error cleaning up expired participants:', error);
    }
};

// Pre-save hook to update the color based on participants
SectorSchema.pre('save', function (next) {
    if (this.participants.length > 0) {
        this.color = '#FFA500'; // Orange when occupied
    } else {
        this.color = '#00FF00'; // Green when empty
    }
    next();
});

const Sector = model<ISector>('Sector', SectorSchema);

// Cleanup job to remove expired participants every 5 minutes
const cleanupJob = setInterval(async () => {
    try {
        await Sector.cleanupExpiredParticipants();
    } catch (error) {
        console.error('Error during scheduled cleanup:', error);
    }
}, 5 * 60 * 1000); // Run every 5 minutes

// Graceful shutdown for cleanup job
const shutdownCleanupJob = () => {
    clearInterval(cleanupJob);
    console.log('Cleanup job stopped.');
    process.exit();
};

process.on('SIGINT', shutdownCleanupJob);
process.on('SIGTERM', shutdownCleanupJob);

export default Sector;
export { ISector, IParticipant };
