import { program } from 'commander';

program
  .option('--port <number>', 'Port to listen on')
  .option('--verbose', 'Enable verbose logging')
  .option('--config <path>', 'Path to config file');
