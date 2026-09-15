#!/usr/bin/env bash
# Lance l'app Flutter en serveur Web (port 8080), détachée du terminal.
# Usage : bash .devcontainer/run-web.sh   puis ouvrir le port 8080 forwardé.
set -e
export PATH="$PATH:$HOME/flutter/bin"
cd "$(dirname "$0")/.."

pkill -f "flutter run" 2>/dev/null || true
sleep 1
rm -f /tmp/run.log

setsid nohup flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  "$@" > /tmp/run.log 2>&1 < /dev/null &

echo "flutter run démarré (pid $!)"
echo "Logs   : tail -f /tmp/run.log"
echo "Attendre la ligne « is being served at http://0.0.0.0:8080 » puis ouvrir le port 8080."
