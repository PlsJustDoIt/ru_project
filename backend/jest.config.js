/** @type {import('ts-jest').JestConfigWithTsJest} **/
export default {
    collectCoverage: true,
    collectCoverageFrom: ['src/**/*.ts'],
    verbose: true,
    testEnvironment: 'node',
    transform: {
        '^.+\\.tsx?$': ['ts-jest', {
            useESM: true,
            tsconfig: {
                // Surcharge les options spécifiquement pour ts-jest
                target: 'ES2022',
                module: 'NodeNext',
            },
        }],
    },
    extensionsToTreatAsEsm: ['.ts'],
    moduleNameMapper: {
        '^(\\.{1,2}/.*)\\.js$': '$1',
    },
    moduleFileExtensions: ['ts', 'js', 'json', 'node'],
};
