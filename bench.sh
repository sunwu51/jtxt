#!/bin/bash
# Node vs Bun 大文件处理 benchmark（3 次取最优，记录峰值 RSS）
cd "$(dirname "$0")"

run() {
  local label="$1"; shift
  local best=999999 rss=0
  for i in 1 2 3; do
    local out
    out=$(/usr/bin/time -l "$@" 2>&1 >/dev/null)
    local real ms r
    real=$(echo "$out" | awk '/real/ {print $1; exit}')
    r=$(echo "$out" | awk '/maximum resident set size/ {print $1; exit}')
    [ -n "$r" ] && rss=$r
    ms=$(echo "$real" | awk '{printf "%d", $1*1000}')
    [ "$ms" -lt "$best" ] && best=$ms
  done
  printf "%-26s best=%6dms   peakRSS=%6dMB\n" "$label" "$best" $((rss/1024/1024))
}

echo "== 参照: 系统工具 =="
run "wc -l"            wc -l bench.txt
run "awk 词数统计"      awk '{c+=NF} END{print c}' bench.txt

echo "== 场景1: 纯行计数（readline 吞吐） =="
run "node"  node jtxt.js 'ctx.n1++' -e 'console.log(ctx.n1)' bench.txt
run "bun"   bun  jtxt.js 'ctx.n1++' -e 'console.log(ctx.n1)' bench.txt

echo "== 场景2: 字符串过滤 =="
run "node"  node jtxt.js 'if (l.includes("abc")) ctx.n1++' -e 'console.log(ctx.n1)' bench.txt
run "bun"   bun  jtxt.js 'if (l.includes("abc")) ctx.n1++' -e 'console.log(ctx.n1)' bench.txt

echo "== 场景3: 词数统计（split） =="
run "node"  node jtxt.js 'ctx.n1 += l.split(" ").length' -e 'console.log(ctx.n1)' bench.txt
run "bun"   bun  jtxt.js 'ctx.n1 += l.split(" ").length' -e 'console.log(ctx.n1)' bench.txt

echo "== 场景4: 正则匹配 =="
run "node"  node jtxt.js 'if (/^\[2026.*[0-9]{5}$/.test(l)) ctx.n1++' -e 'console.log(ctx.n1)' bench.txt
run "bun"   bun  jtxt.js 'if (/^\[2026.*[0-9]{5}$/.test(l)) ctx.n1++' -e 'console.log(ctx.n1)' bench.txt
