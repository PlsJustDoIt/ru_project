const config = {
    preset: 'ts-jest/presets/default-esm',
    testEnvironment: 'node',
    moduleNameMapper: {
        '(.+)\\.js': '$1',
    },
    transform: {
        '^.+\\.tsx?$': [
            'ts-jest',
            {
                diagnostics: true,
                useESM: true,
                tsconfig: 'tsconfig.json',
                moduleResolution: 'NodeNext',
            },
        ],
    },
    extensionsToTreatAsEsm: ['.ts'],
    collectCoverage: true,
};

export default config;
