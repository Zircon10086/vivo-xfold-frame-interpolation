#!/usr/bin/env bash
# 手工构建 Xposed 模块 APK：javac + aapt2 + d8 + zipalign + apksigner
set -euo pipefail
cd "$(dirname "$0")"

SDK=../../xfold-2-unlock/build-env/sdk
AJAR="$SDK/platforms/android-37.2/android.jar"
BT="$SDK/build-tools/37.0.0"
OUT=build
rm -rf "$OUT"
mkdir -p "$OUT/stub" "$OUT/classes" "$OUT/dex"

find stubs -name '*.java' > "$OUT/stub.txt"
javac --release 11 -nowarn -cp "$AJAR" -d "$OUT/stub" @"$OUT/stub.txt"

find src -name '*.java' > "$OUT/src.txt"
javac --release 11 -nowarn -cp "$AJAR;$OUT/stub" -d "$OUT/classes" @"$OUT/src.txt"

"$BT/aapt2.exe" link -o "$OUT/base.apk" -I "$AJAR" \
    --manifest AndroidManifest.xml -A assets \
    --min-sdk-version 26 --target-sdk-version 34

find "$OUT/classes" -name '*.class' > "$OUT/classes.txt"
java -cp "$BT/lib/d8.jar" com.android.tools.r8.D8 --min-api 26 --lib "$AJAR" \
    --output "$OUT/dex" @"$OUT/classes.txt"

cp "$OUT/base.apk" "$OUT/unsigned.apk"
python - "$OUT" <<'PY'
import shutil
import sys
import zipfile

out = sys.argv[1]
shutil.copyfile(out + "/base.apk", out + "/unsigned.apk")
with zipfile.ZipFile(out + "/unsigned.apk", "a", zipfile.ZIP_DEFLATED) as apk:
    apk.write(out + "/dex/classes.dex", "classes.dex")
PY

"$BT/zipalign.exe" -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"

KEY="debug.keystore"
if [ ! -f "$KEY" ]; then
    keytool -genkeypair -keystore "$KEY" -storepass android -keypass android \
        -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
        -keyalg RSA -keysize 2048 -validity 10000 >/dev/null 2>&1
fi
java -jar "$BT/lib/apksigner.jar" sign --ks "$KEY" --ks-pass pass:android \
    --key-pass pass:android --out vivo-memc-v0.4.apk "$OUT/aligned.apk"
java -jar "$BT/lib/apksigner.jar" verify vivo-memc-v0.4.apk
ls -l vivo-memc-v0.4.apk
