#!/usr/bin/env node
import { parseArgs, run } from '../src/cli.js';

const args = process.argv.slice(2);
try {
  const opts = parseArgs(args);
  await run(opts);
} catch (err) {
  console.error(err.message);
  process.exit(1);
}
