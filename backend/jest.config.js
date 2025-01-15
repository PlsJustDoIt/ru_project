const config = {
    preset: 'ts-jest/presets/default-esm',
    testEnvironment: 'node',
    moduleNameMapper: {
        '^(\\.{1,2}/.*)\\.js$': '$1',
    },
    transform: {
        '^.+\\.tsx?$': [
            'ts-jest',
            {
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
