#!/usr/bin/env bash
# Installe la chaîne Android (Java 17 + SDK) si besoin, puis construit l'APK release.
# Prérequis : android/app/google-services.json doit être présent (non versionné).
set -euo pipefail
cd "$(dirname "$0")/.."

export PATH="$PATH:$HOME/flutter/bin"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"

echo "▶ Java 17…"
if ! command -v java >/dev/null || ! java -version 2>&1 | grep -q '"17'; then
  sudo apt-get update -y -qq
  sudo apt-get install -y -qq openjdk-17-jdk
fi
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
echo "  JAVA_HOME=$JAVA_HOME"

echo "▶ Android SDK…"
CLT="$ANDROID_SDK_ROOT/cmdline-tools/latest"
if [ ! -x "$CLT/bin/sdkmanager" ]; then
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/clt.zip" "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  unzip -q "$tmp/clt.zip" -d "$tmp"
  rm -rf "$CLT"; mkdir -p "$CLT"
  mv "$tmp/cmdline-tools/"* "$CLT/"
  rm -rf "$tmp"
fi
export PATH="$PATH:$CLT/bin:$ANDROID_SDK_ROOT/platform-tools"

yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null 2>&1 || true
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-35" \
  "build-tools;35.0.0" \
  "ndk;27.0.12077973" >/dev/null

flutter config --android-sdk "$ANDROID_SDK_ROOT" --no-analytics >/dev/null

echo "▶ google-services.json…"
if [ ! -f android/app/google-services.json ]; then
  echo "✗ android/app/google-services.json manquant — abandon." >&2
  exit 3
fi

echo "▶ flutter build apk --release…"
flutter pub get
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
ls -la "$APK"
echo "✅ APK : $(pwd)/$APK"
