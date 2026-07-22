---
name: jtxt
description: "A line-oriented text processing CLI that uses JavaScript syntax (an awk alternative). Use it to filter, transform, or aggregate logs/text files, or to run arbitrary per-line JS logic with await support (fetch, shell commands, etc.). Triggers: text processing, log analysis, awk replacement, line-by-line processing, aggregation, jtxt. For plain search/matching without custom logic, prefer rg/grep."
---

# jtxt

A CLI tool for line-oriented text processing with JavaScript syntax, positioned as an awk alternative. It streams input line by line and can handle GB-scale files.

## When to use

- **Filtering** with conditions too complex for grep (e.g. regex + length + computation combined)
- **Transforming** lines (extract fields, reformat, `JSON.parse` for JSON Lines, etc.)
- **Cross-line aggregation** (count, sum, group-by, TopN — things awk can do but with painful syntax)
- **Side effects per line**: call HTTP APIs (`fetch`) or run shell commands (`exec`)
- Large file processing (streaming, memory usage independent of file size)

**Do NOT use for**: plain text search (use rg — an order of magnitude faster) or recursive directory search (jtxt only accepts a single file or stdin).

## How to run

```bash
jtxt [options] <logic> [filename]   # when installed globally (npm i -g jtxt)
node jtxt.js <logic> [filename]     # run directly inside this repo (bun jtxt.js also works)

# options:
#   -b, --begin <code>  run once before processing (initialization)
#   -e, --end <code>    run once after all lines are read (summary output)
# reads stdin when no filename is given, so it composes with pipes
```

`logic` is a piece of JavaScript compiled into an **async function** invoked once per line. Lines are processed strictly sequentially: the next line is only read after the previous line's awaits settle.

## Injected variables and functions

| Name | Description |
|---|---|
| `l` | Current line content (string, without the trailing newline) |
| `ctx` | Preset context object `{ n1:0, n2:0, n3:0, s:'', arr:[] }` for accumulating state across lines; you can also attach any custom property (e.g. `ctx.m = {}`) |
| `print` | Alias of `console.log` |
| `exec(cmd)` | **async**. Runs a shell command (via `/bin/sh`, pipes supported), resolves to stdout as a string (trailing newline trimmed). Throws on non-zero exit; the error carries `code`/`stdout`/`stderr` |
| `execSync(cmd)` | Synchronous version of `exec`, handy in begin/end blocks |

The logic runs in global scope, so `JSON`, `Math`, `Date`, `RegExp`, `Promise`, `fetch` (Node 18+), `process`, etc. are available out of the box. **`require` is NOT available** (shell out via `exec` if you really need a module).

## Examples

```bash
# Filter: lines containing only digits
jtxt 'if (l.match(/^\d+$/)) console.log(l)' app.log

# Aggregate: request count per hour (begin initializes, end reports)
jtxt -b 'ctx.m={}' 'var k = "h" + new Date(l.substring(0,19)).getHours(); ctx.m[k]=(ctx.m[k]||0)+1' -e 'console.log(ctx.m)' app.log

# Transform: parse JSON Lines and extract fields
jtxt 'try { const o = JSON.parse(l); if (o.level === "ERROR") console.log(o.ts, o.msg) } catch {}' app.log

# await: call an HTTP API for each line
jtxt 'const r = await fetch("https://api.example.com/u/" + l); console.log(l, r.status)' ids.txt

# exec: run a shell command on filtered lines
jtxt 'if (l.includes("ERROR")) console.log(await exec("say " + JSON.stringify(l)))' app.log

# execSync: fetch environment info once in begin
jtxt -b 'ctx.v = execSync("git rev-parse --short HEAD")' 'ctx.n1++' -e 'console.log(ctx.v, ctx.n1)' app.log

# Compose: search with rg first, then process with jtxt
rg 'ERROR' app.log | jtxt 'ctx.arr.push(l)' -e 'console.log(ctx.arr.length)'
```

## Caveats

- **Quoting**: wrap logic in single quotes on POSIX shells (multi-line logic can simply span lines inside the quotes); Windows cmd requires double quotes.
- **exec cost**: every call spawns a subprocess — never run it on every line of a huge file; filter first or use it in begin/end.
- **exec/await require jtxt >= 0.1.8** — check with `jtxt -V`.
- Per-line awaits are sequential: total time for fetch/exec logic ≈ lines × per-call latency. Suited for low-frequency side effects, not high-concurrency scraping.
- An exception on one line does not abort processing; it prints `Error processing line:` and continues with the next line.
