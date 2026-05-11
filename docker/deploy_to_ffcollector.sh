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
    healthcheck_ffcollector.sh healthcheck.env.example \
    "$FFCOLLECTOR:$REMOTE_DIR/"

# 3. Scripts ausführbar machen
ssh "$FFCOLLECTOR" "mkdir -p $REMOTE_DIR/systemd && chmod +x $REMOTE_DIR/migrate.sh $REMOTE_DIR/upload.sh $REMOTE_DIR/healthcheck_ffcollector.sh"
scp systemd/ffcollector-healthcheck.service systemd/ffcollector-healthcheck.timer \
    "$FFCOLLECTOR:$REMOTE_DIR/systemd/"

echo ""
echo "Dateien übertragen. Jetzt auf ffcollector:"
echo "  ssh $FFCOLLECTOR"
echo "  cd $REMOTE_DIR"
echo "  ./migrate.sh"
echo ""
echo "Danach Cron für Upload einrichten:"
echo "  crontab -e"
echo "  */5 * * * * $REMOTE_DIR/upload.sh >> $REMOTE_DIR/upload.log 2>&1"
echo ""
echo "Optional: Health-Check aktivieren (Telegram/Mail):"
echo "  cp $REMOTE_DIR/healthcheck.env.example $REMOTE_DIR/healthcheck.env"
echo "  nano $REMOTE_DIR/healthcheck.env"
echo "  sudo cp $REMOTE_DIR/systemd/ffcollector-healthcheck.* /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable --now ffcollector-healthcheck.timer"
