#!/usr/bin/env bash
# Builds matrixshapes.apk without Gradle: aapt2 -> javac -> d8 -> zipalign -> apksigner
set -euo pipefail
cd "$(dirname "$0")"
SDK="${ANDROID_SDK:-$LOCALAPPDATA/Android/Sdk}"
BT="$SDK/build-tools/android-14"
JAR="$SDK/platforms/android-34/android.jar"
OUT=build; rm -rf "$OUT"; mkdir -p "$OUT/res" "$OUT/classes" "$OUT/gen"
"$BT/aapt2.exe" compile --dir app/res -o "$OUT/res.zip"
"$BT/aapt2.exe" link -o "$OUT/unsigned.apk" -I "$JAR" --manifest app/AndroidManifest.xml \
  -A app/assets --java "$OUT/gen" "$OUT/res.zip"
javac -nowarn -source 8 -target 8 -bootclasspath "$JAR" -d "$OUT/classes" \
  $(find app/src "$OUT/gen" -name '*.java') 2>&1 | grep -v 'warning' || true
cmd //c "$BT/d8.bat" --release --lib "$JAR" --min-api 24 --output "$OUT" $(find "$OUT/classes" -name '*.class')
(cd "$OUT" && python -c "import zipfile;z=zipfile.ZipFile('unsigned.apk','a');z.write('classes.dex');z.close()")
"$BT/zipalign.exe" -f 4 "$OUT/unsigned.apk" "$OUT/aligned.apk"
KS=debug.keystore
export PATH="$PATH:/c/Program Files/Java/jdk-17/bin"
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass android -keypass android -alias debug \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Matrix Shapes Debug" >/dev/null
cmd //c "$BT/apksigner.bat" sign --ks "$KS" --ks-pass pass:android --out matrixshapes.apk "$OUT/aligned.apk"
ls -la matrixshapes.apk
