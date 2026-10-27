import { createServer } from 'node:http';
import { createReadStream, statSync, existsSync } from 'node:fs';
import { resolve, extname, sep } from 'node:path';
const root = resolve(import.meta.dirname, '..', process.argv[3] || 'build/web');
const port = Number(process.argv[2] || 8791);
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.wasm': 'application/wasm', '.svg': 'image/svg+xml', '.png': 'image/png', '.pck': 'application/octet-stream' };
createServer((req, res) => {
  let file;
  try { file = resolve(root, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname.replace(/\/$/, '/index.html'))); }
  catch { res.writeHead(400).end(); return; }
  if (!file.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try {
    const contentType=mime[extname(file)] || 'application/octet-stream';
    const compressed=/\bgzip\b/.test(req.headers['accept-encoding']||'') && existsSync(file+'.gz');
    if(compressed)file+='.gz';
    const stat = statSync(file);
    if (!stat.isFile()) throw new Error('not a file');
    res.writeHead(200, { 'Content-Type': contentType, 'Content-Length': stat.size, 'Cache-Control': 'no-store', 'Vary':'Accept-Encoding', ...(compressed?{'Content-Encoding':'gzip'}:{}) });
    createReadStream(file).pipe(res);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log(`COURT RUSH local preview: http://127.0.0.1:${port}/`));
