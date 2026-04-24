#!/usr/bin/env python3
"""
Generiert Knoten-Statistik-PNGs aus InfluxDB und lädt sie zu Netcup FTP hoch.
Läuft als Docker-Container, getriggert per Cron alle 5 Minuten.
"""
import os
import ssl
import ftplib
from datetime import datetime, timezone

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from influxdb import InfluxDBClient

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------
INFLUX_HOST = "localhost"
INFLUX_PORT = 8086
INFLUX_DB   = "freifunk"

FTP_HOST    = os.environ.get("FTP_HOST", "af991.netcup.net")
FTP_USER    = os.environ.get("FTP_USER", "hosting102099")
FTP_PASS    = os.environ.get("FTP_PASS", "")
FTP_DIR     = "/freifunk/json/graphs"

OUTPUT_DIR  = "/app/output"

CHARTS = [
    {"field": "clients.total", "label": "Clients",    "color": "#1f77b4", "suffix": "clients"},
    {"field": "load",          "label": "CPU Load",   "color": "#d62728", "suffix": "load"},
    {"field": "time.up",       "label": "Uptime (s)", "color": "#2ca02c", "suffix": "uptime"},
]

# ---------------------------------------------------------------------------

def make_chart(node_id, hostname, times, values, label, color, suffix):
    fig, ax = plt.subplots(figsize=(6, 2.5))
    ax.plot(times, values, color=color, linewidth=1.5)
    ax.fill_between(times, values, alpha=0.15, color=color)
    ax.set_ylabel(label, fontsize=9)
    ax.set_title(hostname, fontsize=10, fontweight='bold')
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%d.%m'))
    ax.xaxis.set_major_locator(mdates.DayLocator())
    fig.autofmt_xdate(rotation=30)
    ax.grid(True, alpha=0.25)
    ax.set_xlim(times[0], times[-1])
    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, f"{node_id}_{suffix}.png")
    plt.savefig(path, dpi=100, bbox_inches='tight')
    plt.close(fig)
    return path


def generate_all():
    client = InfluxDBClient(host=INFLUX_HOST, port=INFLUX_PORT, database=INFLUX_DB)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Alle Knoten mit Hostname holen
    rs = client.query('SELECT last("clients.total") FROM "node" GROUP BY "nodeid", "hostname"')
    nodes = {}
    for series in rs.raw.get('series', []):
        tags = series.get('tags', {})
        nid  = tags.get('nodeid')
        name = tags.get('hostname', nid)
        if nid:
            nodes[nid] = name

    if not nodes:
        print("Keine Knoten in InfluxDB — noch keine Daten vorhanden.")
        return []

    print(f"{len(nodes)} Knoten gefunden.")
    generated = []

    for node_id, hostname in nodes.items():
        for chart in CHARTS:
            field  = chart['field']
            # Erst 7 Tage mit 1h-Auflösung versuchen, bei zu wenig Daten auf 6h/5m zurückfallen
            rs_ts  = client.query(f"""
                SELECT mean("{field}") AS val
                FROM "node"
                WHERE "nodeid" = '{node_id}' AND time > now() - 7d
                GROUP BY time(1h) fill(none)
            """)
            points = [p for p in rs_ts.get_points() if p.get('val') is not None]
            if len(points) < 1:
                rs_ts = client.query(f"""
                    SELECT mean("{field}") AS val
                    FROM "node"
                    WHERE "nodeid" = '{node_id}' AND time > now() - 6h
                    GROUP BY time(5m) fill(none)
                """)
            points = [p for p in rs_ts.get_points() if p.get('val') is not None]
            if len(points) < 1:
                continue

            times  = [datetime.fromisoformat(p['time'].replace('Z', '+00:00')) for p in points]
            values = [p['val'] for p in points]

            path = make_chart(node_id, hostname, times, values,
                              chart['label'], chart['color'], chart['suffix'])
            generated.append(path)

    print(f"{len(generated)} Grafiken erzeugt.")
    return generated


def upload_ftp(files):
    if not files:
        return

    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode    = ssl.CERT_NONE

    ftp = ftplib.FTP_TLS(context=context)
    ftp.connect(FTP_HOST, 21)
    ftp.login(FTP_USER, FTP_PASS)
    ftp.prot_p()

    # Verzeichnis anlegen falls nicht vorhanden
    try:
        ftp.mkd(FTP_DIR)
    except ftplib.error_perm:
        pass
    ftp.cwd(FTP_DIR)

    ok = err = 0
    for path in files:
        name = os.path.basename(path)
        try:
            with open(path, 'rb') as f:
                ftp.storbinary(f'STOR {name}', f)
            ok += 1
        except Exception as e:
            print(f"  FEHLER {name}: {e}")
            err += 1

    ftp.quit()
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"{ts}  Upload: {ok} OK, {err} Fehler")


if __name__ == '__main__':
    files = generate_all()
    upload_ftp(files)
