import path from 'path';
import winston from 'winston';


const isProduction = process.env.NODE_ENV === 'production';

const logger = winston.createLogger({
level: 'info',
format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message }) => {
        return `${timestamp} ${level}: ${message}`;
    })
),
transports: [
    new winston.transports.Console(),
]
});

if (isProduction) {
    const __dirname = path.dirname(path.resolve())+'logs';
    logger.add(new winston.transports.File({ filename: 'server.log', dirname: __dirname }));
    logger.add(new winston.transports.File({ filename: 'error.log', dirname: __dirname ,level: 'error' }));
}
export default logger;