import { join } from 'path';
import { createLogger, format, transports } from 'winston';
import { existsSync, mkdirSync } from 'fs';
import { isProduction } from '../config.js';
import { rootDir } from '../config.js';

const logger = createLogger({
    level: 'info',
    format: format.combine(
        format.timestamp({ format: 'DD-MM-YYYY HH:mm:ss' }),
        format.prettyPrint({ colorize: true }),
        format.json(),
        format.splat(),
        format.colorize({ message: true }),
        format.printf(({ timestamp, level, message }) => {
            return `${timestamp} ${level}: ${message}`;
        }),
    ),
    transports: [
        new transports.Console(),
    ],
});

if (isProduction) {
    const __dirname = join(rootDir, 'logs');

    // Vérifie si le dossier 'logs' existe, et le crée s'il n'existe pas
    if (!existsSync(__dirname)) {
        mkdirSync(__dirname, { recursive: true });
    }

    logger.add(new transports.File({ filename: 'server.log',
        dirname: __dirname,
        maxsize: 100000,
        maxFiles: 1 }));
    logger.add(new transports.File({ filename: 'error.log',
        dirname: __dirname,
        level: 'error',
        maxsize: 100000,
        maxFiles: 1 }));
}
export default logger;
