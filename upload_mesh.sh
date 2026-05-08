#!/bin/bash

HOST="${FTP_HOST:?Bitte FTP_HOST als Umgebungsvariable setzen}"
USER="${FTP_USER:?Bitte FTP_USER als Umgebungsvariable setzen}"
PASS="${FTP_PASS:?Bitte FTP_PASS als Umgebungsvariable setzen}"

LOCAL_DIR="${LOCAL_DIR:-/home/openclaw/freifunk/yanicmap/data}"
REMOTE_DIR="${FTP_REMOTE_DIR:-/freifunk/json}"

# Upload aller JSON-Dateien per curl (FTP mit TLS)
for FILE in "$LOCAL_DIR"/*; do
    BASENAME=$(basename "$FILE")
    echo "Uploading $BASENAME ..."
    curl --silent --show-error \
        --ftp-ssl \
        --insecure \
        -u "$USER:$PASS" \
        -T "$FILE" \
        "ftp://$HOST/$REMOTE_DIR/$BASENAME"
done
echo "Upload abgeschlossen."
