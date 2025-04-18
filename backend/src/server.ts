import app, { setupRoutes } from './app.js';
import logger from './utils/logger.js';
import { socketService } from './routes/socket/socket.service.js';
import swaggerSetup from './modules/swagger.js';
import adminJsSetup from './modules/admin.js';
import { isProduction, rootDir } from './config.js';
import { createWriteStream } from 'fs';
import { join } from 'path';
import morgan from 'morgan';
import { setupRestaurant } from './routes/ru/ru.service.js';
import connectDB from './modules/db.js';

// Logging
if (isProduction) {
    logger.info('lancement en production');
    const accessLogStream = createWriteStream(join(rootDir, 'logs', 'access.log'), { flags: 'a+' });
    app.use(morgan('combined', { stream: accessLogStream }));
} else {
    logger.info('lancement en dev');
    app.use(morgan('dev'));
}

setupRoutes(app);

logger.info('MONGO_URI: ' + process.env.MONGO_URI);
logger.info('API Key : ' + process.env.GINKO_API_KEY);

// mongoose.connect(process.env.MONGO_URI)
//     .then(() => {
//         logger.info('MongoDB Connected');

//     })
//     .catch(err => logger.error('MongoDB connection error:', err));

await connectDB();

setupRestaurant();

swaggerSetup(app);
adminJsSetup(app);

const PORT = process.env.PORT || 5000;

const server = app.listen(PORT, () => {
    logger.info(`Server running on port ${PORT}`);
});

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

// Attach Socket.IO to the existing server
socketService.initialize(server);

export default server;
