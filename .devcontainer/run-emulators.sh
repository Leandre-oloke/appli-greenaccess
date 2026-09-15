#!/usr/bin/env bash
# Installe firebase-tools si besoin, compile les Cloud Functions, puis démarre
# la suite d'émulateurs Firebase (Auth, Firestore, Functions, Storage).
# UI sur http://localhost:4000 (port forwardé automatiquement en Codespace).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v firebase >/dev/null 2>&1 || npm install -g firebase-tools

echo "▶ Cloud Functions…"
npm --prefix functions install
npm --prefix functions run build

echo "▶ Démarrage des émulateurs (projet : $(node -pe "require('./.firebaserc').projects.default" 2>/dev/null || echo greenaccess-16d25))…"
firebase emulators:start
