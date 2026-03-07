import { Schema, model } from 'mongoose';

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

const BugReport = model('BugReport', BugReportSchema);

export default BugReport;
