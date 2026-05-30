/** @type {import('ts-jest').JestConfigWithTsJest} **/
export default {
    // Coverage est opt-in : `npm run test:coverage` (ou `jest --coverage`).
    // L'activer par défaut instrumentait tout `src/` à chaque run (~25x plus lent).
    collectCoverageFrom: ['src/**/*.ts'],
    testEnvironment: 'node',
    transform: {
        '^.+\\.tsx?$': ['ts-jest', {
            useESM: true,
            tsconfig: {
                // Surcharge les options spécifiquement pour ts-jest.
                // Pour les tests on émet de l'ESM "pur" (ESNext) plutôt que NodeNext :
                // cela permet d'activer isolatedModules, qui transpile sans
                // re-vérifier les types (déjà couverts par `tsc --noEmit`).
                // Gain net : pas de type-check par worker → suites bien plus rapides
                // en parallèle, et plus de warning TS151002.
                target: 'ES2022',
                module: 'ESNext',
                isolatedModules: true,
            },
        }],
    },
    extensionsToTreatAsEsm: ['.ts'],
    moduleNameMapper: {
        '^(\\.{1,2}/.*)\\.js$': '$1',
    },
    moduleFileExtensions: ['ts', 'js', 'json', 'node'],
};
