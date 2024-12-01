import globals from 'globals';
import pluginJs from '@eslint/js';
import tseslint from 'typescript-eslint';
import stylistic from '@stylistic/eslint-plugin';
import unusedImports from 'eslint-plugin-unused-imports';

export default [
    {
        files: ['**/*.{js,mjs,cjs,ts}'], // Fichiers à inclure
        languageOptions: {
            globals: globals.browser, // Options de langage et globaux
        },
        rules: {
            // Ajoute ici tes règles ESLint
            // "no-console": "warn", // Exemple : avertissement pour les consoles.log
            // "eqeqeq": "error", // Exemple : forcer l'utilisation de === au lieu de ==
            // "semi": ["error", "always"], // Exemple : imposer les points-virgules
            // "quotes": ["error", "double"], // Exemple : imposer les guillemets doubles
            //  "no-array-constructor": "error",
            'no-unused-vars': 'off', // or "@typescript-eslint/no-unused-vars": "off",
            'unused-imports/no-unused-imports': 'error',
            'unused-imports/no-unused-vars': [
                'warn',
                {
                    vars: 'all',
                    varsIgnorePattern: '^_',
                    args: 'after-used',
                    argsIgnorePattern: '^_',
                },
            ],
        },
        plugins: {
            'unused-imports': unusedImports,
        },
    },
    pluginJs.configs.recommended, // Configuration recommandée du plugin JavaScript
    ...tseslint.configs.recommended, // Configuration recommandée TypeScript ESLint
    stylistic.configs.customize({
        indent: 4,
        quotes: 'single',
        semi: true,
        jsx: true,
        braceStyle: '1tbs',
        // ...
    }),
];
