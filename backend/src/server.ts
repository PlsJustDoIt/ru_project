// src/server.js

import app from './app.js';
import logger from './services/logger.js';
import { socketService } from './services/socket.js';

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
