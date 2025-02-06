import { config } from 'dotenv';
import { join, resolve } from 'path';
config();

const isProduction = process.env.NODE_ENV === 'production';

// Calcul dynamique du chemin
const rootDir = isProduction
    ? join(resolve(), '..') // En production (dossier "dist"), remonte d'un niveau
    : resolve(); // En développement, reste dans le dossier courant

const uploadsPath = join(rootDir, 'uploads');
const logsPath = join(rootDir, 'logs');
const avatarPath = join(uploadsPath, 'avatar');
const bugReportPath = join(uploadsPath, 'bugReport');
let componentsPath: string;
console.log('isProduction: ' + isProduction);
if (!isProduction) {
    componentsPath = join(rootDir, 'src/components');
} else {
    componentsPath = join(resolve(), 'components');
}

export {
    isProduction,
    rootDir,
    uploadsPath,
    logsPath,
    avatarPath,
    bugReportPath,
    componentsPath,

};
