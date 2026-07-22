// 快速生成约 500MB 的随机日志文件（缓冲写入，比 file_gen.js 逐行 append 快得多）
const fs = require('fs');

const filePath = __dirname + '/bench.txt';
const target = 500 * 1024 * 1024; // 500MB
const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function rnd(len) {
  let s = '';
  for (let i = 0; i < len; i++) s += chars[(Math.random() * chars.length) | 0];
  return s;
}

const fd = fs.openSync(filePath, 'w');
let written = 0;
let lines = 0;
while (written < target) {
  let chunk = '';
  for (let i = 0; i < 2000; i++) {
    chunk += `[2026-07-22 10:15:30] Request ${rnd(80 + ((Math.random() * 100) | 0))}\n`;
    lines++;
  }
  written += fs.writeSync(fd, chunk);
}
fs.closeSync(fd);
console.log(`done: ${(written / 1024 / 1024).toFixed(1)}MB, ${lines} lines`);
