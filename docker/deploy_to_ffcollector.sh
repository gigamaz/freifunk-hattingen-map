#!/bin/bash
# Überträgt das Docker-Setup auf ffcollector und startet die Migration
# Auf openclaw ausführen

set -e

FFCOLLECTOR="marcus@ffcollector"
REMOTE_DIR="/home/marcus/ffmap/docker"

echo "=== Deploy Docker-Setup auf ffcollector ==="

# 1. Verzeichnis auf ffcollector anlegen
ssh "$FFCOLLECTOR" "mkdir -p $REMOTE_DIR"

# 2. Dateien übertragen
echo "Übertrage Dateien..."
scp Dockerfile docker-compose.yml yanic.toml mcast_join.py migrate.sh upload.sh \
    "$FFCOLLECTOR:$REMOTE_DIR/"

# 3. Scripts ausführbar machen
ssh "$FFCOLLECTOR" "chmod +x $REMOTE_DIR/migrate.sh $REMOTE_DIR/upload.sh"

echo ""
echo "Dateien übertragen. Jetzt auf ffcollector:"
echo "  ssh $FFCOLLECTOR"
echo "  cd $REMOTE_DIR"
echo "  ./migrate.sh"
echo ""
echo "Danach Cron für Upload einrichten:"
echo "  crontab -e"
echo "  */5 * * * * $REMOTE_DIR/upload.sh >> $REMOTE_DIR/upload.log 2>&1"
