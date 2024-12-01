import express from 'express';
import mongoose from 'mongoose';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import ruRoutes from './routes/ru.js';
import ginkoRoutes from './routes/ginko.js';
import cors from 'cors';
import fs from 'fs';
// import https from 'https';
import path from 'path';
import morgan from 'morgan';
import logger from './services/logger.js';
import { exit } from 'process';
import dotenv from 'dotenv';

if (process.env.NODE_ENV !== 'production') {
    dotenv.config();
}

const app = express();
logger.info('MONGO_URI: ' + process.env.MONGO_URI);

mongoose.set('strictQuery', false);

const isProduction = process.env.NODE_ENV === 'production';

if (isProduction) {
    console.log('lancement en production');
} else {
    console.log('lancement en dev');
}

if (isProduction) {
    // define dirnames
    const __dirname = path.dirname(path.resolve());
    // set up log file stream in logs folder
    const accessLogStream = fs.createWriteStream(path.join(__dirname, 'logs', 'access.log'), { flags: 'a+' });
    // log requests combined format
    app.use(morgan('combined', { stream: accessLogStream }));
} else {
    app.use(morgan('dev'));
}

if (process.env.MONGO_URI == null) {
    logger.error('MONGO_URI is not defined');
    exit(1);
}

mongoose.connect(process.env.MONGO_URI)
    .then(() => logger.info('MongoDB Connected'))
    .catch(err => logger.error('MongoDB connection error:', err));

app.use(express.json());
app.use(cors());
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/ru', ruRoutes);
app.use('/api/uploads', express.static('uploads'));
app.use('/api/ginko', ginkoRoutes);

const PORT = process.env.PORT || 5000;

// if (!isProduction) {
//   app.listen(PORT, () => logger.info(`Server http running on port ${PORT}`));
// } else {
//   const options = {
//     key: fs.readFileSync('/etc/ssl/private/server.key'),
//     cert: fs.readFileSync('/etc/ssl/certs/server.crt')
//   };
//   const server = https.createServer(options,app);
//   server.listen(PORT, () => logger.info(`Server https running on port ${PORT}`));
// }

app.listen(PORT, () => logger.info(`Server http running on port ${PORT}`));
