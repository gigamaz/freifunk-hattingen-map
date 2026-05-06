# Freifunk Hattingen Karte (Yanic + Meshviewer)

Dieses Repository enthaelt den Betrieb fuer die visualisierte Karte aller
Freifunk-Hattingen-Knoten.

## Projektkern

- Datensammlung: Yanic (Respondd ueber `bat0`)
- Ausgabe: `meshviewer.json`, `nodes.json`, `graph.json`, `nodelist.json`, `nodes.geojson`
- Visualisierung: Meshviewer

## Wichtige Dokumente

- `YANICMAP_DOKUMENTATION.md`
- `DATEIANALYSE.md`

## Verzeichnisueberblick

- `yanicmap/`: lokales/systemd-orientiertes Setup
- `docker/`: containerisiertes Setup fuer ffcollector
- `upload_mesh.sh`: Upload-Skript fuer JSON/GeoJSON

## Schnellstart (Docker)

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
```

Danach liegen die Exportdateien unter `docker/data/` und koennen von dort
hochgeladen bzw. per Webserver bereitgestellt werden.
