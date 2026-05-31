import app, { setupRoutes } from './app.js';
import { connect } from 'mongoose';
import logger from './utils/logger.js';
import { setupSocketApplicationEvents } from './routes/socket/socket.service.js';
import { socketHandler } from './utils/socket.js';
import swaggerSetup from './modules/swagger.js';
import adminJsSetup from './modules/admin.js';
import { isProduction, mongoUri, rootDir } from './config.js';
import { createWriteStream, readFileSync } from 'fs';
import { createServer as createHttpServer } from 'http';
import { createServer as createHttpsServer } from 'https';
import { join } from 'path';
import morgan from 'morgan';
import { setupUploadDirectories } from './utils/fileSystem.js';

console.log('isProduction: ' + isProduction);

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

connect(mongoUri)
    .then(() => logger.info('MongoDB Connected'))
    .catch(err => logger.error('MongoDB connection error:', err));

swaggerSetup(app);
adminJsSetup(app);

const PORT = process.env.PORT || 5000;

// HTTPS direct UNIQUEMENT si les certificats sont fournis via SSL_KEY_PATH /
// SSL_CERT_PATH. Sinon on sert en HTTP : c'est le cas normal derrière un
// reverse-proxy (nginx) qui termine déjà le TLS. En développement aussi.
const createServer = () => {
    const keyPath = process.env.SSL_KEY_PATH;
    const certPath = process.env.SSL_CERT_PATH;
    if (keyPath && certPath) {
        return createHttpsServer({
            key: readFileSync(keyPath),
            cert: readFileSync(certPath),
        }, app);
    }
    if (isProduction) {
        logger.info('SSL_KEY_PATH/SSL_CERT_PATH absents : HTTP (TLS attendu via reverse-proxy)');
    }
    return createHttpServer(app);
};

const useHttps = Boolean(process.env.SSL_KEY_PATH && process.env.SSL_CERT_PATH);

const server = createServer();
server.listen(PORT, () => {
    logger.info(`Server running on port ${PORT} (${useHttps ? 'HTTPS' : 'HTTP'})`);
});

// Attach Socket.IO to the existing server
socketHandler.initialize(server, isProduction);
setupSocketApplicationEvents();

export default server;
