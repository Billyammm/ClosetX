#!/usr/bin/env node
// Static file server for the ClosetX Flutter web build.
//
//   node tools/serve-web.mjs            -> http://localhost:8080
//   node tools/serve-web.mjs --port 5000
//
// Serves `build/web` (run `flutter build web` first). Unknown paths fall back
// to index.html so Flutter's router owns navigation instead of the server.

import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';

const ROOT = resolve(process.cwd(), 'build', 'web');
const DEFAULT_PORT = 8080;

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.glb': 'model/gltf-binary',
  '.gltf': 'model/gltf+json',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.task': 'application/octet-stream',
  '.binarypb': 'application/octet-stream',
};

const NO_CACHE = new Set(['.html', '.js', '.json']);

function parsePort(argv) {
  const index = argv.indexOf('--port');
  if (index === -1) return DEFAULT_PORT;
  const port = Number.parseInt(argv[index + 1] ?? '', 10);
  return Number.isInteger(port) && port > 0 ? port : DEFAULT_PORT;
}

/** Resolves a request path to a readable file inside ROOT, or null. */
async function resolveFile(urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0]);
  const relative = normalize(decoded).replace(/^([/\\])+/, '');
  const candidate = join(ROOT, relative);
  if (candidate !== ROOT && !candidate.startsWith(ROOT + sep)) return null;

  const info = await stat(candidate).catch(() => null);
  if (info?.isDirectory()) {
    const indexFile = join(candidate, 'index.html');
    return (await stat(indexFile).catch(() => null)) ? indexFile : null;
  }
  return info?.isFile() ? candidate : null;
}

function sendFile(response, filePath, statusCode = 200) {
  const extension = extname(filePath).toLowerCase();
  response.writeHead(statusCode, {
    'Content-Type': MIME_TYPES[extension] ?? 'application/octet-stream',
    'Cache-Control': NO_CACHE.has(extension)
        ? 'no-cache'
        : 'public, max-age=3600',
  });
  createReadStream(filePath).pipe(response);
}

const server = createServer(async (request, response) => {
  const urlPath = request.url ?? '/';
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD' }).end();
    return;
  }

  const filePath = await resolveFile(urlPath);
  if (filePath) {
    sendFile(response, filePath);
    return;
  }

  sendFile(response, join(ROOT, 'index.html'));
});

const port = parsePort(process.argv.slice(2));
server.listen(port, () => {
  console.log(`ClosetX web app: http://localhost:${port}`);
  console.log(`Serving: ${ROOT}`);
});
