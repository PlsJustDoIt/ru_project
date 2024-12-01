import path from 'path';
import winston from 'winston';
import fs from 'fs';

const isProduction = process.env.NODE_ENV === 'production';

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp({ format: 'DD-MM-YYYY HH:mm:ss' }),
        winston.format.prettyPrint({ colorize: true }),
        winston.format.colorize({ message: true }),
        winston.format.printf(({ timestamp, level, message }) => {
            return `${timestamp} ${level}: ${message}`;
        }),
    ),
    transports: [
        new winston.transports.Console(),
    ],
});

if (isProduction) {
    const __dirname = path.dirname(path.resolve()) + '/logs';

    // Vérifie si le dossier 'logs' existe, et le crée s'il n'existe pas
    if (!fs.existsSync(__dirname)) {
        fs.mkdirSync(__dirname, { recursive: true });
    }

    logger.add(new winston.transports.File({ filename: 'server.log',
        dirname: __dirname,
        maxsize: 100000,
        maxFiles: 1 }));
    logger.add(new winston.transports.File({ filename: 'error.log',
        dirname: __dirname,
        level: 'error',
        maxsize: 100000,
        maxFiles: 1 }));
}
export default logger;
