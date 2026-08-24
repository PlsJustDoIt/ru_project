/**
 * Migration one-shot : répare les secteurs de RU Lumière (r135) en PRÉSERVANT
 * le `_id` du restaurant — donc sans orphaniser les utilisateurs (qui référencent
 * le resto par son `_id` Mongo via `user.restaurant`).
 *
 * Opère directement sur les collections (PAS via les modèles Mongoose ni config.ts) :
 *   - évite de tirer `mongoose-sequence` (erreurs de type esModuleInterop/doublons) ;
 *   - évite la validation d'env de config.ts (GINKO_API_KEY, JWT_*…) ;
 *   - pose `sectorId` 1..9 explicitement (pas de course du plugin auto-increment).
 *
 * Ce que fait le script :
 *   1. trouve le resto r135 (par le champ `restaurantId`, PAS par _id) ;
 *   2. corrige `name` si absent/null ;
 *   3. supprime les secteurs legacy rattachés à ce resto (sectorId vide / ancien format) ;
 *   4. réinitialise le compteur auto-increment `sectorId` ;
 *   5. recrée 9 secteurs avec sectorId 1..9 explicites ;
 *   6. relie les nouveaux secteurs au resto (même _id) et vérifie.
 *
 * ⚠️ DESTRUCTIF sur la collection `sectors`.
 *   - local (utilise le .env) :  cd backend && npx tsx src/scripts/fix-ru-lumiere-sectors.ts
 *   - prod (override l'URI)    :  cd backend && MONGO_URI="<URI_PROD>" npx tsx src/scripts/fix-ru-lumiere-sectors.ts
 *
 * NB : si la création de secteurs est un jour rebranchée au runtime (modèle + plugin),
 * réamorcer le compteur `counters` à 9 pour éviter une collision sur l'index unique
 * { restaurant, sectorId }.
 */
import { config } from 'dotenv';
import mongoose from 'mongoose';

// Charge .env (pour MONGO_URI) sans la validation stricte de config.ts.
config();

const RU_ID = 'r135';

// Coordonnées extraites de la base locale (source de vérité), secteurs 1..9.
const SECTOR_LAYOUT = [
    { position: { x: 10, y: 6 }, size: { width: 20, height: 10 } },
    { position: { x: 32, y: 7 }, size: { width: 36, height: 18 } },
    { position: { x: 70, y: 6 }, size: { width: 20, height: 10 } },
    { position: { x: 10, y: 17 }, size: { width: 20, height: 20 } },
    { position: { x: 70, y: 17 }, size: { width: 20, height: 20 } },
    { position: { x: 10, y: 39 }, size: { width: 20, height: 20 } },
    { position: { x: 70, y: 39 }, size: { width: 20, height: 20 } },
    { position: { x: 10, y: 60.3 }, size: { width: 20, height: 10 } },
    { position: { x: 70, y: 60.3 }, size: { width: 20, height: 10 } },
];

async function main() {
    const uri = process.env.MONGO_URI;
    if (!uri) {
        throw new Error('MONGO_URI manquant — défini dans .env ou passé en variable d\'environnement.');
    }
    await mongoose.connect(uri);
    console.log('Connecté à MongoDB');

    const db = mongoose.connection;
    const restaurants = db.collection('restaurants');
    const sectors = db.collection('sectors');

    const resto = await restaurants.findOne({ restaurantId: RU_ID });
    if (!resto) {
        throw new Error(`Restaurant ${RU_ID} introuvable — abandon (création non gérée ici pour ne pas changer le _id).`);
    }
    const existingSectorIds = Array.isArray(resto.sectors) ? resto.sectors : [];
    console.log(`Resto trouvé: _id=${resto._id} name=${JSON.stringify(resto.name)} sectors=${existingSectorIds.length}`);

    // 2. nom manquant/null
    if (!resto.name) {
        await restaurants.updateOne({ _id: resto._id }, { $set: { name: 'RU Lumière' } });
        console.log('name corrigé -> "RU Lumière"');
    }

    // 3. supprime les secteurs legacy de CE resto (par ref ET par ids listés)
    const del = await sectors.deleteMany({
        $or: [{ restaurant: resto._id }, { _id: { $in: existingSectorIds } }],
    });
    console.log(`Secteurs supprimés: ${del.deletedCount}`);

    // 4. reset du compteur auto-increment (mongoose-sequence -> collection "counters")
    const resetCounters = await db.collection('counters').deleteMany({ id: 'sectorId' });
    console.log(`Compteurs sectorId réinitialisés: ${resetCounters.deletedCount}`);

    // 4bis. supprime les index legacy (ex: participants.userId_1_name_1 d'un ancien
    // schéma de secteurs) : ils font échouer l'insert en doublon (null, null).
    for (const ix of await sectors.indexes()) {
        if (ix.name && ix.name !== '_id_') {
            await sectors.dropIndex(ix.name);
            console.log(`Index legacy supprimé: ${ix.name}`);
        }
    }

    // 5. recrée 9 secteurs avec sectorId 1..9 explicites
    const docs = SECTOR_LAYOUT.map((layout, i) => ({
        position: layout.position,
        size: layout.size,
        restaurant: resto._id,
        sectorId: i + 1,
    }));
    const ins = await sectors.insertMany(docs);
    const newIds = Object.values(ins.insertedIds);
    console.log(`Secteurs recréés: ${newIds.length}`);

    // 6. relie au resto (même _id) + recrée l'index métier conforme au schéma
    await restaurants.updateOne({ _id: resto._id }, { $set: { sectors: newIds } });
    await sectors.createIndex({ restaurant: 1, sectorId: 1 }, { unique: true });
    console.log('Index { restaurant, sectorId } (unique) recréé.');

    const check = await sectors
        .find({ restaurant: resto._id })
        .project({ sectorId: 1, position: 1, size: 1 })
        .sort({ sectorId: 1 })
        .toArray();
    console.log('\nVérification:');
    console.log(`  resto _id INCHANGÉ: ${resto._id} (users toujours rattachés)`);
    console.log(`  secteurs sectorId: ${check.map(s => s.sectorId).join(', ')}`);
    if (check.some(s => s.sectorId == null)) {
        throw new Error('Au moins un sectorId est null après recréation.');
    }

    await mongoose.connection.close();
    console.log('\nTerminé ✅');
}

main().catch(async (e) => {
    console.error('ÉCHEC migration:', e);
    await mongoose.connection.close().catch(() => {});
    process.exit(1);
});
