import app, { setupRoutes } from './app.js';
import { connect } from 'mongoose';
import logger from './utils/logger.js';
import { setupSocketApplicationEvents } from './routes/socket/socket.service.js';
import { socketHandler } from './utils/socket.js';
import swaggerSetup from './modules/swagger.js';
import adminJsSetup from './modules/admin.js';
import { exit } from 'process';
import { isProduction, rootDir } from './config.js';
import { createWriteStream } from 'fs';
import { join } from 'path';
import morgan from 'morgan';
import { setupUploadDirectories } from './utils/fileSystem.js';

console.log('isProduction: ' + isProduction);
// Database Connection
if (process.env.MONGO_URI == null) {
    logger.error('MONGO_URI is not defined');
    exit(1);
}

// Logging
if (isProduction) {
    console.log('lancement en production');
    const accessLogStream = createWriteStream(join(rootDir, 'logs', 'access.log'), { flags: 'a+' });
    app.use(morgan('combined', { stream: accessLogStream }));
} else {
    console.log('lancement en dev');
    app.use(morgan('dev'));
}

await setupUploadDirectories();
setupRoutes(app);

logger.info('MONGO_URI: ' + process.env.MONGO_URI);
logger.info('API Key : ' + process.env.GINKO_API_KEY);
connect(process.env.MONGO_URI)
    .then(() => logger.info('MongoDB Connected'))
    .catch(err => logger.error('MongoDB connection error:', err));

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
socketHandler.initialize(server, isProduction);
setupSocketApplicationEvents();

export default server;
