import { config } from 'dotenv';
import { join, resolve } from 'path';

config();

const isProduction = process.env.NODE_ENV === 'production';

/**
 * Valide la présence des variables d'environnement obligatoires au démarrage,
 * pour éviter les secrets de repli en dur et les `undefined` silencieux.
 */
const requireEnv = (name: string): string => {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Missing required environment variable: ${name}`);
    }
    return value;
};

const ginkoApiKey = requireEnv('GINKO_API_KEY');
const mongoUri = requireEnv('MONGO_URI');
const jwtAccessSecret = requireEnv('JWT_ACCESS_SECRET');
const jwtRefreshSecret = requireEnv('JWT_REFRESH_SECRET');

// Calcul dynamique du chemin
const rootDir = isProduction
    ? join(resolve(), '..') // En production (dossier "dist"), remonte d'un niveau
    : resolve(); // En développement, reste dans le dossier courant

const uploadsPath = join(rootDir, 'uploads');
const logsPath = join(rootDir, 'logs');
const avatarPath = join(uploadsPath, 'avatar');
const bugReportPath = join(uploadsPath, 'bugReport');
let componentsPath: string;
if (!isProduction) {
    componentsPath = join(rootDir, 'src/components');
} else {
    componentsPath = join(resolve(), 'components');
}
// componentsPath = join(rootDir, 'src/components');

export {
    isProduction,
    rootDir,
    uploadsPath,
    logsPath,
    avatarPath,
    bugReportPath,
    componentsPath,
    ginkoApiKey,
    mongoUri,
    jwtAccessSecret,
    jwtRefreshSecret,
};
