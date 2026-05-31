/**
 * Migration one-shot : répare les secteurs de RU Lumière (r135) en PRÉSERVANT
 * le `_id` du restaurant — donc sans orphaniser les utilisateurs (qui référencent
 * le resto par son `_id` Mongo via `user.restaurant`).
 *
 * Ce que fait le script :
 *   1. trouve le resto r135 (par le champ `restaurantId`, PAS par _id) ;
 *   2. corrige `name` si absent/null ;
 *   3. supprime les secteurs legacy rattachés à ce resto (sectorId vide / ancien format) ;
 *   4. réinitialise le compteur auto-increment `sectorId` ;
 *   5. recrée 9 secteurs SÉQUENTIELLEMENT (évite la course du compteur de Promise.all) ;
 *   6. relie les nouveaux secteurs au resto (même _id) et vérifie.
 *
 * ⚠️ DESTRUCTIF sur la collection `sectors`. À lancer délibérément contre la prod :
 *     cd backend && MONGO_URI="<URI_PROD>" npx tsx src/scripts/fix-ru-lumiere-sectors.ts
 */
import { connect, connection, Types } from 'mongoose';
import { mongoUri } from '../config.js';
import Restaurant from '../models/restaurant.js';
import Sector from '../models/sector.js';

const RU_ID = 'r135';

const SECTOR_LAYOUT = [
    { position: { x: 10, y: 10 }, size: { width: 20, height: 15 } },
    { position: { x: 40, y: 10 }, size: { width: 20, height: 15 } },
    { position: { x: 70, y: 10 }, size: { width: 20, height: 15 } },
    { position: { x: 10, y: 30 }, size: { width: 20, height: 15 } },
    { position: { x: 70, y: 30 }, size: { width: 20, height: 15 } },
    { position: { x: 10, y: 50 }, size: { width: 20, height: 15 } },
    { position: { x: 70, y: 50 }, size: { width: 20, height: 15 } },
    { position: { x: 10, y: 70 }, size: { width: 20, height: 15 } },
    { position: { x: 70, y: 70 }, size: { width: 20, height: 15 } },
];

async function main() {
    await connect(mongoUri);
    console.log('Connecté à MongoDB');

    const resto = await Restaurant.findOne({ restaurantId: RU_ID });
    if (!resto) {
        throw new Error(`Restaurant ${RU_ID} introuvable — abandon (création non gérée ici pour ne pas changer le _id).`);
    }
    console.log(`Resto trouvé: _id=${resto._id} name=${JSON.stringify(resto.name)} sectors=${resto.sectors.length}`);

    // 2. nom manquant/null
    if (!resto.name) {
        resto.name = 'RU Lumière';
        console.log('name corrigé -> "RU Lumière"');
    }

    // 3. supprime les secteurs legacy de CE resto (par ref ET par ids listés)
    const del = await Sector.deleteMany({
        $or: [{ restaurant: resto._id }, { _id: { $in: resto.sectors } }],
    });
    console.log(`Secteurs supprimés: ${del.deletedCount}`);

    // 4. reset du compteur auto-increment (mongoose-sequence -> collection "counters")
    const resetCounters = await connection.collection('counters').deleteMany({ id: 'sectorId' });
    console.log(`Compteurs sectorId réinitialisés: ${resetCounters.deletedCount}`);

    // 5. recrée 9 secteurs SÉQUENTIELLEMENT (sectorId 1..9 via le plugin)
    const newIds: Types.ObjectId[] = [];
    for (const layout of SECTOR_LAYOUT) {
        const s = await Sector.create({ ...layout, restaurant: resto._id });
        newIds.push(s._id);
        console.log(`  secteur créé sectorId=${s.sectorId} _id=${s._id}`);
    }

    // 6. relie au resto (même _id) + vérif
    resto.sectors = newIds;
    await resto.save();

    const check = await Sector.find({ restaurant: resto._id })
        .select('sectorId position size')
        .sort({ sectorId: 1 });
    console.log('\nVérification:');
    console.log(`  resto _id INCHANGÉ: ${resto._id} (users toujours rattachés)`);
    console.log(`  secteurs: ${check.map((s) => s.sectorId).join(', ')}`);
    if (check.some((s) => s.sectorId == null)) {
        throw new Error('Au moins un sectorId est null après recréation — vérifier le plugin/counters.');
    }

    await connection.close();
    console.log('\nTerminé ✅');
}

main().catch(async (e) => {
    console.error('ÉCHEC migration:', e);
    await connection.close().catch(() => {});
    process.exit(1);
});
