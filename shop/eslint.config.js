'use strict';

// Flat config. Haelt shop/ auf einem konsistenten Grundstandard - genau die Art
// Basis-Qualitaet, die der elevate-Skill selbst verkauft (Review-Befund: Schuster
// mit den schlechtesten Schuhen). eslint ist devDependency, bleibt Dependency-Insel.
const js = require('@eslint/js');

module.exports = [
  js.configs.recommended,
  {
    files: ['src/**/*.js', 'bin/**/*.js', 'test/**/*.js', 'eslint.config.js'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'commonjs',
      globals: {
        require: 'readonly', module: 'writable', process: 'readonly', console: 'readonly',
        __dirname: 'readonly', Buffer: 'readonly', fetch: 'readonly', URL: 'readonly',
        URLSearchParams: 'readonly', performance: 'readonly', setTimeout: 'readonly',
      },
    },
    rules: {
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_', caughtErrors: 'none' }],
    },
  },
  {
    files: ['public/**/*.js'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'script',
      globals: {
        window: 'readonly', document: 'readonly', fetch: 'readonly', history: 'readonly',
        localStorage: 'readonly', URLSearchParams: 'readonly', FormData: 'readonly',
        module: 'writable', self: 'readonly', location: 'readonly',
      },
    },
    rules: {
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_', caughtErrors: 'none' }],
    },
  },
];
