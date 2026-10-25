import { cpSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const dashboardDirectory = dirname(fileURLToPath(import.meta.url));
const sourceDirectory = resolve(dashboardDirectory, '..', 'web', 'tryon');
const outputDirectory = process.argv[2]
  ? resolve(process.argv[2])
  : resolve(dashboardDirectory, 'tryon');

cpSync(sourceDirectory, outputDirectory, { recursive: true });
