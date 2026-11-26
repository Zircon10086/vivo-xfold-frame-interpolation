#!/usr/bin/env bash
# 打包 KernelSU 模块：module/ -> dist/vivo-xfold-frame-interpolation-v<version>.zip
# 需要一个可用的 python（Windows 上 "python"，Linux/macOS 上 "python3"）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/module"
VER="$(sed -n 's/^version=//p' "$MOD/module.prop")"
OUT="$ROOT/dist/vivo-xfold-frame-interpolation-$VER.zip"

PY=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then
    PY="$c"
    break
  fi
done
if [ -z "$PY" ]; then
  echo "需要可用的 python3/python 才能打包" >&2
  exit 1
fi

"$PY" "$ROOT/scripts/build_zip.py" "$MOD" "$OUT"
