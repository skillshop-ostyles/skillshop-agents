// Fixture for api-surface-documenter: commander CLI commands.
import { Command } from 'commander';

const program = new Command();

program
    .name('deploy')
    .description('Deploy the application to a target environment');

/**
 * Deploy command.
 * @param {string} env - target environment (staging, production)
 */
program
    .command('deploy')
    .option('--env <env>', 'target environment')
    .action((options) => {
        console.log('Deploying to', options.env);
    });

/**
 * Rollback command.
 * @param {string} version - version to rollback to
 */
program
    .command('rollback')
    .option('--version <version>', 'version to rollback to')
    .action((options) => {
        console.log('Rolling back to', options.version);
    });

program.parse(process.argv);
