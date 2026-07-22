#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { program } = require('commander');
const { exec: cpExec, execSync: cpExecSync } = require('child_process');
const { promisify } = require('util');

// 定义命令行选项
program
  .version('1.0.0')
  .argument('<logic>', '处理逻辑的 JavaScript 代码')
  .argument('[filename]', '要读取的文件名', null)
  .option('-b, --begin <code>', '初始化的逻辑代码')
  .option('-e, --end <code>', '结束后的逻辑代码')
  .parse(process.argv);

// 解析命令行参数
const options = program.opts();
const logic = program.args[0];
const filename = program.args[1];

// 使用 AsyncFunction 构造器，支持在 logic 中使用 await
const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;

var beginFunc = async function(){}, endFunc = async function(){},
    processFunc = new AsyncFunction('l', 'ctx', 'print', 'exec', 'execSync', logic);
if (options.begin) {
    beginFunc = new AsyncFunction('ctx', 'print', 'exec', 'execSync', options.begin);
}
if (options.end) {
    endFunc = new AsyncFunction('ctx', 'print', 'exec', 'execSync', options.end);
}

// 预定义全局变量
var ctx = {
    n1: 0, n2: 0, n3: 0, s: '', arr: []
};
var print = console.log;

// 注入给 logic 的 shell 执行能力，返回 stdout 字符串（去掉末尾换行）
// exec 为异步版本（需 await），execSync 为同步版本；命令非零退出会抛错
const execP = promisify(cpExec);
const exec = async (cmd) => (await execP(cmd, { encoding: 'utf8' })).stdout.replace(/\r?\n$/, '');
const execSync = (cmd) => cpExecSync(cmd, { encoding: 'utf8' }).replace(/\r?\n$/, '');

// 处理文件或标准输入，逐行串行 await，保证 end 在所有行处理完成后才执行
const processStream = async (stream) => {
  await beginFunc(ctx, print, exec, execSync);
  const rl = readline.createInterface({
    input: stream,
    crlfDelay: Infinity // 适用于 \r\n 和 \n 换行符
  });

  for await (const line of rl) {
    try {
        await processFunc(line, ctx, print, exec, execSync);
    } catch (error) {
        console.error('Error processing line:', error);
    }
  }

  // 执行结束逻辑
  await endFunc(ctx, print, exec, execSync);
};

// 判断处理文件还是标准输入
if (filename) {
  try {
    const filePath = path.resolve(filename);
    const fileStream = fs.createReadStream(filePath);
    fileStream.on('error', (err) => {
      console.error(`Error reading file: ${err.message}`);
      process.exit(1);
    });
    processStream(fileStream);
  } catch (err) {
    console.error(`Error processing file path: ${err.message}`);
    process.exit(1);
  }
} else {
  processStream(process.stdin);
}
