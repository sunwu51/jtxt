#!/bin/bash
# 四工具对比 benchmark: jtxt(node) / awk / rg / wc
# 测试文件: bench.txt (500MB 随机日志, 由 bench_gen.js 生成)，每条命令跑 3 次取最优
cd "$(dirname "$0")"
[ -f bench.txt ] || node bench_gen.js

t() { # t <cmd...> -> 最优耗时(ms)
  local best=999999
  for i in 1 2 3; do
    local s=$(date +%s%N)
    "$@" >/dev/null 2>&1
    local e=$(date +%s%N)
    local ms=$(( (e-s)/1000000 ))
    [ $ms -lt $best ] && best=$ms
  done
  echo $best
}

echo "scenario | jtxt(node) | awk | rg | wc"
printf "行计数 | %sms | %sms | %sms | %sms\n" \
  "$(t node jtxt.js 'ctx.n1++' -e 'console.log(ctx.n1)' bench.txt)" \
  "$(t awk 'END{print NR}' bench.txt)" \
  "$(t rg -c '' bench.txt)" \
  "$(t wc -l bench.txt)"
printf "子串过滤(abc) | %sms | %sms | %sms | -\n" \
  "$(t node jtxt.js 'if (l.includes("abc")) ctx.n1++' -e 'console.log(ctx.n1)' bench.txt)" \
  "$(t awk 'index($0,"abc"){c++} END{print c}' bench.txt)" \
  "$(t rg -F -c 'abc' bench.txt)"
printf "词数统计 | %sms | %sms | %sms | %sms\n" \
  "$(t node jtxt.js 'ctx.n1 += l.split(" ").length' -e 'console.log(ctx.n1)' bench.txt)" \
  "$(t awk '{c+=NF} END{print c}' bench.txt)" \
  "$(t rg --count-matches '\S+' bench.txt)" \
  "$(t wc -w bench.txt)"
printf "正则匹配([0-9]{5}\$) | %sms | %sms | %sms | -\n" \
  "$(t node jtxt.js 'if (/[0-9]{5}$/.test(l)) ctx.n1++' -e 'console.log(ctx.n1)' bench.txt)" \
  "$(t awk '/[0-9]{5}$/{c++} END{print c}' bench.txt)" \
  "$(t rg -c '[0-9]{5}$' bench.txt)"
