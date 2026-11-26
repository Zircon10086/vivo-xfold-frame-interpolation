#!/usr/bin/env bash
# 用环境变量模拟不同机型，验证 customize.sh 的分支（不需要真机）
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SH="$ROOT/module/customize.sh"

run() { # $1=label $2=model $3=device $4=expect(0=pass,1=abort)
  out="$(VIVO_MODEL="$2" VIVO_DEVICE="$3" VIVO_MARKET="${4:-模拟}" sh "$SH" 2>&1)"
  rc=$?
  if [ "$5" = "0" ]; then
    if [ $rc -eq 0 ]; then echo "PASS  $1"; else echo "FAIL  $1 (rc=$rc)"; echo "$out" | tail -3; fi
  else
    if [ $rc -ne 0 ]; then echo "PASS  $1 (拒绝)"; else echo "FAIL  $1 应被拒绝"; fi
  fi
}

run "X Fold2 (V2266A/PD2266)" "V2266A" "PD2266" "模拟" 0
run "X Fold3 Pro (V2337A/PD2337)" "V2337A" "PD2337" "模拟" 0
run "X Fold6 (V2545A/PD2507)" "V2545A" "PD2507" "模拟" 0
run "X Fold (无芯片)" "V2178A" "PD2178" "模拟" 1
run "X Fold+ (无芯片)" "V2229A" "PD2229" "模拟" 1
run "X Fold3 (无芯片)" "V2329A" "PD2329" "模拟" 1
run "X Fold5 (无芯片)" "V2436A" "PD2436" "模拟" 1
run "X100 (非折叠)" "V2324A" "PD2324" "模拟" 1
run "未知设备" "V9999A" "PD9999" "模拟" 1
