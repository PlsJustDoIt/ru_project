import { Schema, Document, Types, model } from 'mongoose';
import { mongoose } from '../modules/db.js'; // Importez mongoose depuis votre fichier de connexion
import AutoIncrementFactory from 'mongoose-sequence';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const AutoIncrement = AutoIncrementFactory(mongoose as any); // TODO : désactiver ça le jour où les types pour mongoose-sequence seront fix

interface ISector extends Document {
    _id: Types.ObjectId;
    position: { x: number; y: number };
    size: { width: number; height: number };
    restaurant: Types.ObjectId;
    sectorId: number;
}
const SectorSchema = new Schema(
    {
        restaurant: { type: Schema.Types.ObjectId, ref: 'Restaurant', required: true },
        sectorId: { type: Number },
        position: {
            x: { type: Number, required: true },
            y: { type: Number, required: true },
        },
        size: {
            width: { type: Number, required: true },
            height: { type: Number, required: true },
        },
    },
);

SectorSchema.index({ restaurant: 1, sectorId: 1 }, { unique: true });

// SectorSchema.pre('save', async function (next) {
//     try {
//         // Vérifier si c'est un nouveau document et si aucun sectorId n'est défini
//         if (this.isNew && !(this as any).sectorId) {
//             console.log('Nouveau secteur détecté, génération du sectorId');

//             // Utiliser directement le nom du modèle
//             const SectorModel = model('Sector');

//             // Déboguer la requête
//             console.log('Restaurant ID:', (this as any).restaurant);

//             const lastSector = await (SectorModel as any)
//                 .findOne({ restaurant: (this as any).restaurant })
//                 .sort({ sectorId: -1 })
//                 .lean() // Pour performance
//                 .exec();

//             console.log('Dernier secteur trouvé:', lastSector);

//             // Définir explicitement à 1 si aucun secteur trouvé
//             if (!lastSector) {
//                 (this as any).sectorId = 1;
//                 console.log('Premier secteur, sectorId défini à 1');
//             } else {
//                 // S'assurer que la valeur est un nombre et l'incrémenter
//                 const nextId = typeof lastSector.sectorId === 'number'
//                     ? lastSector.sectorId + 1
//                     : parseInt(lastSector.sectorId || '0') + 1;

//                 (this as any).sectorId = nextId;
//                 console.log(`Prochain sectorId défini à ${nextId}`);
//             }
//         }
//         next();
//     } catch (error) {
//         console.error('Erreur dans le middleware sectorId:', error);
//         next();
//     }
// });

// db.counters.updateOne({ reference_value: { restaurant: ObjectId('680118632705126ae3fa86fc') },},{ $set:{ seq:0}})
// eslint-disable-next-line @typescript-eslint/no-explicit-any
SectorSchema.plugin(AutoIncrement as any, {
    inc_field: 'sectorId',
    reference_fields: ['restaurant'],

    id: 'sectorId',
});

const Sector = model<ISector>('Sector', SectorSchema);

export default Sector;
export { ISector, SectorSchema };
