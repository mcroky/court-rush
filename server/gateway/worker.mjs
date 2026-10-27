import { spawn } from 'node:child_process';
import { connect } from 'node:net';
import { EventEmitter } from 'node:events';
import { resolve } from 'node:path';

export class Worker extends EventEmitter {
  ready = false; socket = null; process = null; buffer = ''; lastHealth = 0;
  constructor({ binary, root, port = 32091, exported = false }) {
    super(); this.binary = binary; this.root = root; this.port = port; this.exported = exported;
  }
  start() {
    const args = this.exported ? ['--headless', '--path', this.root, '--main-pack', resolve(this.root, 'server.pck'), '--script', 'res://server/godot/worker.gd'] : ['--headless', '--path', this.root, '--script', 'res://server/godot/worker.gd'];
    this.process = spawn(this.binary, args, { cwd: this.root, env: { ...process.env, CR_WORKER_PORT: String(this.port) }, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
    this.process.stdout.on('data', () => {});
    this.process.stderr.on('data', data => { if (/SCRIPT ERROR|Parse Error/.test(String(data))) this.emit('fault', 'worker_script'); });
    this.process.on('error', () => this.emit('fault', 'worker_spawn'));
    this.process.on('exit', () => { this.ready = false; this.emit('fault', 'worker_exit'); });
    this.connecting = true; this.connectAttempt(0);
  }
  connectAttempt(attempt) {
    if (!this.connecting) return;
    const socket = connect({ host: '127.0.0.1', port: this.port });
    socket.setNoDelay(true); socket.setEncoding('utf8');
    socket.once('error', () => { socket.destroy(); if (attempt < 100) this.retry = setTimeout(() => this.connectAttempt(attempt + 1), 200); else this.emit('fault', 'worker_timeout'); });
    socket.once('connect', () => {
      this.socket = socket; this.connecting = false;
      socket.on('close', () => { this.ready = false; this.emit('fault', 'worker_connection'); });
      socket.on('data', chunk => {
        this.buffer += chunk;
        if (this.buffer.length > 2_000_000) { socket.destroy(); return; }
        let end;
        while ((end = this.buffer.indexOf('\n')) >= 0) {
          const line = this.buffer.slice(0, end); this.buffer = this.buffer.slice(end + 1);
          let message; try { message = JSON.parse(line); } catch { this.emit('fault', 'worker_protocol'); continue; }
          if (message.type === 'ready') { this.ready = true; this.lastHealth = Date.now(); }
          if (message.type === 'health') this.lastHealth = Date.now();
          this.emit('message', message);
        }
      });
    });
  }
  send(message) {
    if (!this.ready || !this.socket?.writable || this.socket.writableLength > 512_000) return false;
    return this.socket.write(JSON.stringify(message) + '\n');
  }
  close() { this.connecting = false; clearTimeout(this.retry); this.socket?.destroy(); this.process?.kill(); }
}
