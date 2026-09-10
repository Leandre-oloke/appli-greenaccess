#!/usr/bin/env bash
# Provisioning du Codespace : Flutter (Web), dépendances Dart + Node, Firebase CLI.
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
FLUTTER_CHANNEL="stable"

echo "▶ Dépendances système (Flutter Linux)…"
sudo apt-get update -y
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa

echo "▶ Installation de Flutter ($FLUTTER_CHANNEL)…"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"
git config --global --add safe.directory "$FLUTTER_DIR"

flutter config --no-analytics --enable-web
flutter --version

echo "▶ Génération du support Web si absent…"
if [ ! -f web/index.html ]; then
  flutter create --platforms=web --project-name greenaccess .
fi

echo "▶ Dépendances Flutter…"
flutter pub get

echo "▶ Dépendances Cloud Functions…"
npm --prefix functions install

echo "▶ Firebase CLI…"
npm install -g firebase-tools

cat <<'EOF'

✅ Codespace prêt.

Lancer le backend (emulateurs Firebase, optionnel) :
  firebase emulators:start

Lancer l'app en Web :
  # sur le vrai projet Firebase greenaccess-16d25
  flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

  # ou sur les emulateurs locaux
  flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=USE_EMULATOR=true

Puis ouvrir le port 8080 forwardé par Codespaces.
EOF
