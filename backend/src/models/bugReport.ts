import mongoose from 'mongoose';

const bugReportSchema = new mongoose.Schema({
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
    timestamp: {
        type: Date,
        default: Date.now,
    },
});

const BugReport = mongoose.model('BugReport', bugReportSchema);

export default BugReport;
