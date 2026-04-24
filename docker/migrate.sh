#!/bin/bash
# Migration: Alte Yanic-Systemd-Services → Docker
# Auf ffcollector als 'marcus' ausführen
# Voraussetzung: Docker + Docker Compose Plugin installiert

set -e

DOCKER_DIR="/home/marcus/ffmap/docker"
OLD_DIR="/home/marcus/ffmap/yanic"

echo "=== ffcollector: Migration zu Docker ==="
echo ""

# -------------------------------------------------------
# 1. Alte Systemd-Services stoppen und deaktivieren
# -------------------------------------------------------
echo "[1/5] Stoppe alte Systemd-Services..."

for svc in yanic mcast-join; do
    if systemctl --user is-active --quiet "$svc" 2>/dev/null; then
        systemctl --user stop "$svc"
        echo "  Gestoppt: $svc"
    else
        echo "  Bereits gestoppt: $svc"
    fi

    if systemctl --user is-enabled --quiet "$svc" 2>/dev/null; then
        systemctl --user disable "$svc"
        echo "  Deaktiviert: $svc"
    fi
done

systemctl --user daemon-reload
echo "  Systemd-Reload OK"

# -------------------------------------------------------
# 2. Docker-Verzeichnis anlegen
# -------------------------------------------------------
echo "[2/5] Lege Docker-Verzeichnis an: $DOCKER_DIR"
mkdir -p "$DOCKER_DIR/data"

# -------------------------------------------------------
# 3. Alten state.json übernehmen (Node-Cache erhalten!)
# -------------------------------------------------------
echo "[3/5] Übernehme state.json aus altem Setup..."
if [ -f "$OLD_DIR/state.json" ]; then
    cp "$OLD_DIR/state.json" "$DOCKER_DIR/data/state.json"
    echo "  state.json kopiert ($(du -sh "$OLD_DIR/state.json" | cut -f1))"
else
    echo "  Kein state.json gefunden — Yanic startet neu ohne Node-Cache."
fi

# Alte JSON-Daten optional übernehmen
for f in meshviewer.json nodes.json graph.json nodelist.json nodes.geojson; do
    if [ -f "$OLD_DIR/data/$f" ]; then
        cp "$OLD_DIR/data/$f" "$DOCKER_DIR/data/$f"
        echo "  $f kopiert"
    fi
done

# -------------------------------------------------------
# 4. Docker Compose Image bauen und starten
# -------------------------------------------------------
echo "[4/5] Baue Docker-Image und starte Container..."
cd "$DOCKER_DIR"

docker compose build --no-cache
docker compose up -d

echo "  Container gestartet"

# -------------------------------------------------------
# 5. Status prüfen
# -------------------------------------------------------
echo "[5/5] Status:"
sleep 3
docker compose ps

echo ""
echo "=== Migration abgeschlossen ==="
echo ""
echo "Logs live:"
echo "  docker compose logs -f"
echo ""
echo "Daten werden geschrieben nach:"
echo "  $DOCKER_DIR/data/"
echo ""
echo "Alte Daten noch vorhanden unter (zum späteren Aufräumen):"
echo "  $OLD_DIR/"
