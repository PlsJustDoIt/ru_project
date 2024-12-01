import multer from 'multer';
import path from 'path';

const isProduction = process.env.NODE_ENV === 'production';

let uploadDir;

if (isProduction) {
    uploadDir = path.dirname(path.resolve())+'/uploads/avatar';
} else {
    uploadDir = path.resolve()+'/uploads/avatar';
}

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, uploadDir); // Répertoire où les fichiers seront stockés
    },
    filename: (req, file, cb) => {
      const userId = req.user.id; // Assurez-vous que req.user existe et contient un id
      const extension = path.extname(file.originalname); // Garde l'extension originale
      cb(null, `${userId}${extension}`);
    },
  });
  
  // Middleware multer
  const uploadAvatar = multer({
    storage: storage,
    limits: { fileSize: 4 * 1024 * 1024 }, // Limite de taille : 4MB
    fileFilter: (req, file, cb) => {
      const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif'];
      if (allowedMimeTypes.includes(file.mimetype)) {
        cb(null, true);
      } else {
        cb(null, false);
      }
    }
    
});

export default uploadAvatar;