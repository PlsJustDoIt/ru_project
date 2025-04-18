import mongoose from 'mongoose';
import { exit } from 'process';
import logger from '../utils/logger.js';
// Établir la connexion à MongoDB

const connectDB = async () => {
    try {
        if (process.env.MONGO_URI == null) {
            logger.error('MONGO_URI is not defined');
            exit(1);
        }
        await mongoose.connect(process.env.MONGO_URI);
        logger.info('Connexion à MongoDB établie avec succès');
    } catch (err) {
        logger.error('Erreur de connexion à MongoDB:', err);
        process.exit(1);
    }
};

export default connectDB;
export { mongoose };
