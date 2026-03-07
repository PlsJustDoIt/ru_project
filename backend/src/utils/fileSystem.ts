import { mkdir } from 'fs/promises';
import { uploadsPath, bugReportPath, avatarPath } from '../config.js';

export const setupUploadDirectories = async () => {
    try {
        await mkdir(uploadsPath, { recursive: true });
        await mkdir(bugReportPath, { recursive: true });
        await mkdir(avatarPath, { recursive: true });
    } catch (error) {
        throw new Error(`Error creating upload directories: ${error}`);
    }
};
