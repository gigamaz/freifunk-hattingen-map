# Freifunk Hattingen Karte (Yanic + Meshviewer)

Dieses Repository enthält den Betrieb für die visualisierte Karte aller
Freifunk-Hattingen-Knoten.

## Projektkern

- Datensammlung: Yanic (Respondd über `bat0`)
- Ausgabe: `meshviewer.json`, `nodes.json`, `graph.json`, `nodelist.json`, `nodes.geojson`
- Visualisierung: Meshviewer

## Wichtige Dokumente

- `YANICMAP_DOKUMENTATION.md`
- `DATEIANALYSE.md`

## Verzeichnisüberblick

- `yanicmap/`: lokales/systemd-orientiertes Setup
- `docker/`: containerisiertes Setup für ffcollector
- `upload_mesh.sh`: Upload-Skript für JSON/GeoJSON

## Schnellstart (Docker)

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

Danach liegen die Exportdateien unter `docker/data/` und können von dort
hochgeladen bzw. per Webserver bereitgestellt werden.
