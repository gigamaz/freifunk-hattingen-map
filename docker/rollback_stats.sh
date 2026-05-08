#!/bin/bash
# Rollback: Stats-Stack (InfluxDB + Grafana + Graphen) komplett entfernen
# Auf ffcollector als 'marcus' ausführen

set -e
DOCKER_DIR="/home/marcus/ffmap/docker"
FTP_HOST="${FTP_HOST:?Bitte FTP_HOST als Umgebungsvariable setzen}"
FTP_USER="${FTP_USER:?Bitte FTP_USER als Umgebungsvariable setzen}"
FTP_PASS="${FTP_PASS:?Bitte FTP_PASS als Umgebungsvariable setzen}"
FTP_REMOTE_DIR="${FTP_REMOTE_DIR:-/freifunk/meshviewer}"

echo "=== Rollback Stats-Stack ==="

# 1. Container stoppen und entfernen
echo "[1/4] Stoppe InfluxDB + Grafana..."
cd "$DOCKER_DIR"
docker compose -f docker-compose.stats.yml down 2>/dev/null || true

# 2. Cron-Eintrag entfernen
echo "[2/4] Entferne Graph-Cron..."
crontab -l 2>/dev/null | grep -v generate_graphs | crontab - || true

# 3. Meshviewer config.json wiederherstellen
echo "[3/4] Stelle meshviewer config.json wieder her..."
BACKUP=$(curl -s --ftp-ssl --insecure \
    -u "$FTP_USER:$FTP_PASS" \
    "ftp://$FTP_HOST$FTP_REMOTE_DIR/config.json.bak" 2>/dev/null)
if [ -n "$BACKUP" ]; then
    echo "$BACKUP" > /tmp/config.json.restored
    curl -s --ftp-ssl --insecure \
        -u "$FTP_USER:$FTP_PASS" \
        -T /tmp/config.json.restored \
        "ftp://$FTP_HOST$FTP_REMOTE_DIR/config.json"
    echo "  config.json wiederhergestellt aus Backup."
else
    echo "  WARNUNG: Kein Backup gefunden auf FTP."
fi

# 4. Yanic neu starten ohne InfluxDB (config ohne InfluxDB-Sektion)
echo "[4/4] Starte Yanic neu (JSON-only config)..."
docker compose restart yanic

echo ""
echo "=== Rollback abgeschlossen ==="
echo "Daten bleiben erhalten in:"
echo "  $DOCKER_DIR/influxdb-data/   (InfluxDB-Daten)"
echo "  $DOCKER_DIR/grafana-data/    (Grafana-Daten)"
echo "Zum vollständigen Entfernen:"
echo "  rm -rf $DOCKER_DIR/influxdb-data $DOCKER_DIR/grafana-data $DOCKER_DIR/graphs"
