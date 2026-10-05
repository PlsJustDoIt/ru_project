import { parseTrustProxy } from '../app.js';

describe('parseTrustProxy', () => {
    it('par défaut : désactivé hors production', () => {
        // Les tests tournent avec NODE_ENV=test.
        expect(parseTrustProxy(undefined)).toBe(false);
        expect(parseTrustProxy('')).toBe(false);
    });

    it('accepte booléens, nombre de sauts et listes de sous-réseaux', () => {
        expect(parseTrustProxy('true')).toBe(true);
        expect(parseTrustProxy('false')).toBe(false);
        expect(parseTrustProxy('2')).toBe(2);
        expect(parseTrustProxy('loopback, 10.0.0.0/8')).toBe('loopback, 10.0.0.0/8');
    });
});
