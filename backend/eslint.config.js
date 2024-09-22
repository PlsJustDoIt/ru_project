import globals from "globals";
import pluginJs from "@eslint/js";
import tseslint from "typescript-eslint";


export default [
  {
    files: ["**/*.{js,mjs,cjs,ts}"], // Fichiers à inclure
    languageOptions: {
      globals: globals.browser // Options de langage et globaux
    },
    rules: {
      // Ajoute ici tes règles ESLint
      // "no-console": "warn", // Exemple : avertissement pour les consoles.log
      // "eqeqeq": "error", // Exemple : forcer l'utilisation de === au lieu de ==
      // "semi": ["error", "always"], // Exemple : imposer les points-virgules
      // "quotes": ["error", "double"], // Exemple : imposer les guillemets doubles
    //  "no-array-constructor": "error",

    }
  },
  pluginJs.configs.recommended, // Configuration recommandée du plugin JavaScript
  ...tseslint.configs.recommended, // Configuration recommandée TypeScript ESLint
];
