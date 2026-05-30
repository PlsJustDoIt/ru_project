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
    it('n\'insère PAS le week-end intercalé entre deux semaines', () => {
        // ven 2026-06-05 ouvert, lun 2026-06-08 ouvert ; sam 06 / dim 07 ignorés
        const result = fillClosedDays(
            [openDay('2026-06-05'), openDay('2026-06-08')],
            '2026-06-05',
        );
        expect(result.map((m) => m.date)).toEqual([
            '2026-06-05',
            '2026-06-08',
        ]);
        expect(result.every((m) => !isClosed(m))).toBe(true);
    });

    it('insère un jour férié EN SEMAINE absent comme fermé', () => {
        // aujourd'hui = jeudi 2026-06-04 (férié/grève, absent), 1er ouvert = vendredi 2026-06-05
        const result = fillClosedDays(
            [openDay('2026-06-05')],
            '2026-06-04',
        );
        expect(result.map((m) => m.date)).toEqual([
            '2026-06-04',
            '2026-06-05',
        ]);
        expect(isClosed(result[0])).toBe(true);
        expect(isClosed(result[1])).toBe(false);
    });

    it('aujourd\'hui = samedi -> démarre au lundi, aucune chip week-end', () => {
        // aujourd'hui = samedi 2026-05-30, 1er ouvert = lundi 2026-06-01
        const result = fillClosedDays(
            [openDay('2026-06-01')],
            '2026-05-30',
        );
        expect(result.map((m) => m.date)).toEqual(['2026-06-01']);
        expect(isClosed(result[0])).toBe(false);
    });

    it('liste vide un jour de semaine -> un seul jour fermé (aujourd\'hui)', () => {
        // aujourd'hui = lundi 2026-06-01
        const result = fillClosedDays([], '2026-06-01');
        expect(result).toEqual([{ date: '2026-06-01', fermeture: 'Restaurant fermé' }]);
    });

    it('liste vide un week-end -> aucun jour (rien à afficher)', () => {
        const result = fillClosedDays([], '2026-05-30'); // samedi
        expect(result).toEqual([]);
    });

    it('garde un menu réel tombant un week-end (jamais masqué)', () => {
        // certains RU ouvrent le samedi : si le flux fournit un samedi, on le garde
        const result = fillClosedDays([openDay('2026-05-30')], '2026-05-30');
        expect(result.map((m) => m.date)).toEqual(['2026-05-30']);
        expect(isClosed(result[0])).toBe(false);
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
