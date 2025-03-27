import type { Config } from 'jest';

const config: Config = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    roots: ['<rootDir>/src'],
    transform: {
        '^.+\\.tsx?$': 'ts-jest',
    },
    moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json', 'node'],
    testMatch: ['**/*.test.ts', '**/*.spec.ts'],
    collectCoverage: true,
    coverageDirectory: 'coverage',
    coverageProvider: 'v8',
    globals: {
        'ts-jest': {
            tsconfig: 'tsconfig.spec.json',
        },
    },
};

export default config;
