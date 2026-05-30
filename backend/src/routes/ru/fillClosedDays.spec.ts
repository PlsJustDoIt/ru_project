import { fillClosedDays } from './ru.service.js';
import { MenuResponse } from '../../interfaces/menu.js';

// Construit un jour OUVERT minimal pour une date donnée.
function openDay(date: string): MenuResponse {
    return {
        'Entrées': ['Salade'],
        'Cuisine traditionnelle': ['Steak'],
        'Menu végétalien': 'menu non communiqué',
        'Pizza': 'menu non communiqué',
        'Cuisine italienne': 'menu non communiqué',
        'Grill': 'menu non communiqué',
        date,
    };
}

function isClosed(m: MenuResponse): boolean {
    return 'fermeture' in m;
}

describe('fillClosedDays', () => {
    it('comble un week-end intercalé entre deux semaines', () => {
        // ven 2026-06-05 ouvert, lun 2026-06-08 ouvert ; sam 06 / dim 07 absents
        const result = fillClosedDays(
            [openDay('2026-06-05'), openDay('2026-06-08')],
            '2026-06-05',
        );
        expect(result.map((m) => m.date)).toEqual([
            '2026-06-05',
            '2026-06-06',
            '2026-06-07',
            '2026-06-08',
        ]);
        expect(isClosed(result[0])).toBe(false);
        expect(isClosed(result[1])).toBe(true);
        expect(isClosed(result[2])).toBe(true);
        expect(isClosed(result[3])).toBe(false);
    });

    it('insère aujourd\'hui en tête quand il est absent du flux', () => {
        // aujourd'hui = samedi 2026-05-30, 1er jour ouvert = lundi 2026-06-01
        const result = fillClosedDays(
            [openDay('2026-06-01')],
            '2026-05-30',
        );
        expect(result.map((m) => m.date)).toEqual([
            '2026-05-30',
            '2026-05-31',
            '2026-06-01',
        ]);
        expect(isClosed(result[0])).toBe(true);
        expect(isClosed(result[2])).toBe(false);
    });

    it('liste vide -> un seul jour fermé (aujourd\'hui)', () => {
        const result = fillClosedDays([], '2026-05-30');
        expect(result).toEqual([{ date: '2026-05-30', fermeture: 'Restaurant fermé' }]);
    });

    it('semaine pleine sans trou -> liste inchangée', () => {
        const input = [
            openDay('2026-06-01'),
            openDay('2026-06-02'),
            openDay('2026-06-03'),
        ];
        const result = fillClosedDays(input, '2026-06-01');
        expect(result.map((m) => m.date)).toEqual([
            '2026-06-01',
            '2026-06-02',
            '2026-06-03',
        ]);
        expect(result.every((m) => !isClosed(m))).toBe(true);
    });

    it('n\'ajoute aucun jour fermé après le dernier jour ouvert', () => {
        const result = fillClosedDays([openDay('2026-06-01')], '2026-06-01');
        expect(result.map((m) => m.date)).toEqual(['2026-06-01']);
    });
});
