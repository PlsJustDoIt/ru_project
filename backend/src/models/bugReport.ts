import { Schema, model } from 'mongoose';

interface IBugReport extends Document {
    _id: Schema.Types.ObjectId;
    description: string;
    screenshot_url?: string;
    app_version?: string;
    platform?: string;
    status: 'open' | 'resolved' | 'closed';
    severity?: 'low' | 'medium' | 'high' | 'critical';
    user: Schema.Types.ObjectId;
}

const BugReportSchema = new Schema({
    description: {
        type: String,
        required: true,
    },
    screenshot_url: String,
    app_version: String,
    platform: String,
    status: {
        type: String,
        enum: ['open', 'resolved', 'closed'],
        default: 'open',
    },
    severity: {
        type: String,
        enum: ['low', 'medium', 'high', 'critical'],
    },

    user: {
        type: Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },

}, { timestamps: true });

const BugReport = model<IBugReport>('BugReport', BugReportSchema);

export default BugReport;
