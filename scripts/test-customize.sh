#!/usr/bin/env bash
# 用环境变量模拟不同机型，验证 customize.sh 的分支（不需要真机）
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH="$ROOT/module/customize.sh"

run() { # $1=label $2=model $3=device $4=market $5=expect(0=pass,1=abort)
  out="$(VIVO_MODEL="$2" VIVO_DEVICE="$3" VIVO_MARKET="${4:-模拟}" sh "$SH" 2>&1)"
  rc=$?
  if [ "$5" = "0" ]; then
    if [ $rc -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1 (rc=$rc)"; echo "$out" | tail -3; fi
  else
    if [ $rc -ne 0 ]; then echo "PASS  $1 (拒绝)"; else echo "FAIL  $1 应被拒绝"; fi
  fi
}

# 型号（V 编号）判定
run "X Fold2      V2266A" "V2266A" "PD2266" "模拟" 0
run "X Fold3 Pro  V2337A" "V2337A" "PD2337" "模拟" 0
run "X Fold6      V2545A" "V2545A" "PD2507" "模拟" 0
run "X Fold5      V2436A" "V2436A" "PD2436" "模拟" 1
run "X Fold3      V2303A" "V2303A" "PD2303" "模拟" 1
run "X Fold+      V2229A" "V2229A" "PD2229" "模拟" 1
run "X Fold       V2178A" "V2178A" "PD2178" "模拟" 1
run "X100 非折叠  V2324A" "V2324A" "PD2324" "模拟" 1
run "未知设备     V9999A" "V9999A" "PD9999" "模拟" 1

# 只有设备代号、型号为空时的兜底
run "仅代号 PD2266" "" "PD2266" "模拟" 0
run "仅代号 PD2303" "" "PD2303" "模拟" 1
