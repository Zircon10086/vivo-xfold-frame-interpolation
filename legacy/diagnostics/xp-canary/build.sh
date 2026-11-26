#!/usr/bin/env bash
# 构建/安装/验证注入探测器（org.dsh.xptest）。
#
# 用途：回答「Vector 框架到底有没有把 Xposed 模块加载进目标进程」。模块只做一件事：
# 在 handleLoadPackage 里用 android.util.Log 打一行日志（绕开框架的日志收集）。
#
#   bash diagnostics/xp-canary/build.sh            # 只构建
#   bash diagnostics/xp-canary/build.sh --install  # 构建 + 安装 + 设作用域（需 adb 已连）
#
# 结论（2026-11-26 本机实测）：Vector 2.2 在这台 PD2266 上把模块列为「已启用/运行中」，
# 但目标进程里既没有 Xposed 日志也没有这里打的 Log.e —— 模块类从未被加载。
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

SDK=../../../xfold-2-unlock/build-env/sdk
AJAR="$SDK/platforms/android-37.2/android.jar"
BT="$SDK/build-tools/37.0.0"
STUBS=../../xposed-module/stubs
KEY=../../xposed-module/debug.keystore
ADB="$SDK/platform-tools/adb.exe"
OUT=build

rm -rf "$OUT"
mkdir -p "$OUT/stub" "$OUT/classes" "$OUT/dex"

find "$STUBS" -name '*.java' > "$OUT/stub.txt"
javac --release 11 -nowarn -cp "$AJAR" -d "$OUT/stub" @"$OUT/stub.txt"

find src -name '*.java' > "$OUT/src.txt"
javac --release 11 -nowarn -cp "$AJAR;$OUT/stub" -d "$OUT/classes" @"$OUT/src.txt"

"$BT/aapt2.exe" link -o "$OUT/base.apk" -I "$AJAR" \
    --manifest AndroidManifest.xml -A assets \
    --min-sdk-version 26 --target-sdk-version 34

find "$OUT/classes" -name '*.class' > "$OUT/classes.txt"
java -cp "$BT/lib/d8.jar" com.android.tools.r8.D8 --min-api 26 --lib "$AJAR" \
    --output "$OUT/dex" @"$OUT/classes.txt"

python - "$OUT" <<'PY'
import shutil
import sys
import zipfile

out = sys.argv[1]
shutil.copyfile(out + "/base.apk", out + "/unsigned.apk")
with zipfile.ZipFile(out + "/unsigned.apk", "a", zipfile.ZIP_DEFLATED) as apk:
    apk.write(out + "/dex/classes.dex", "classes.dex")
    apk.write("meta/META-INF/xposed/module.prop", "META-INF/xposed/module.prop")
    apk.write("meta/META-INF/xposed/java_init.list", "META-INF/xposed/java_init.list")
PY

"$BT/zipalign.exe" -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
java -jar "$BT/lib/apksigner.jar" sign --ks "$KEY" \
    --ks-pass pass:android --key-pass pass:android \
    --out xp-canary.apk "$OUT/aligned.apk"
java -jar "$BT/lib/apksigner.jar" verify xp-canary.apk
ls -l xp-canary.apk

if [ "${1:-}" = "--install" ]; then
    "$ADB" push xp-canary.apk /data/local/tmp/xp-canary.apk
    "$ADB" shell 'su -c "pm install -r -g /data/local/tmp/xp-canary.apk"'
    "$ADB" shell 'su -c "/data/adb/lspd/cli modules enable org.dsh.xptest --json | head -6; /data/adb/lspd/cli scope set org.dsh.xptest com.android.settings/0 --json | head -6"'
    echo "现在重启框架（su -c 'setprop ctl.restart zygote'），再开一次设置，然后：adb logcat -d | grep XpTest"
fi
