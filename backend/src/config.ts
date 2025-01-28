import path from 'path';
import dotenv from 'dotenv';
dotenv.config();

const isProduction = process.env.NODE_ENV === 'production';

// Calcul dynamique du chemin
const rootDir = isProduction
    ? path.join(path.resolve(), '..') // En production (dossier "dist"), remonte d'un niveau
    : path.resolve(); // En développement, reste dans le dossier courant

const uploadsPath = path.join(rootDir, 'uploads');
const logsPath = path.join(rootDir, 'logs');
const avatarPath = path.join(uploadsPath, 'avatar');
const bugReportPath = path.join(uploadsPath, 'bugReport');
let componentsPath: string;
console.log('isProduction: ' + isProduction);
if (!isProduction) {
    componentsPath = path.join(rootDir, 'src/components');
} else {
    componentsPath = path.join(path.resolve(), 'components');
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
