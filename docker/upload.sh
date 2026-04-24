#!/bin/bash
# Upload JSON-Dateien von ffcollector zu Netcup FTP
# Cron: */5 * * * * /home/marcus/ffmap/docker/upload.sh >> /home/marcus/ffmap/docker/upload.log 2>&1

HOST="af991.netcup.net"
USER="hosting102099"
PASS="${FTP_PASS:?Bitte FTP_PASS als Umgebungsvariable setzen}"

LOCAL_DIR="/home/marcus/ffmap/docker/data"
REMOTE_DIR="/freifunk/json"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

for FILE in "$LOCAL_DIR"/*.json "$LOCAL_DIR"/*.geojson; do
    [ -f "$FILE" ] || continue
    BASENAME=$(basename "$FILE")
    RESULT=$(curl --silent --show-error \
        --ftp-ssl \
        --insecure \
        -u "$USER:$PASS" \
        -T "$FILE" \
        "ftp://$HOST/$REMOTE_DIR/$BASENAME" 2>&1)
    if [ $? -eq 0 ]; then
        echo "$TIMESTAMP  OK  $BASENAME"
    else
        echo "$TIMESTAMP  FEHLER  $BASENAME: $RESULT"
    fi
done
