## Gluon site.mk für Freifunk Hattingen (ffhat)
## Gluon v2023.2.5
##
## Paketliste: Pflichtpakete + ffhat-spezifische Erweiterungen
## Nicht aufgeführt: andere VPN-Typen (out of scope für ffhat — nur L2TP/Tunneldigger)

GLUON_SITE_PACKAGES := \
	gluon-mesh-batman-adv-15 \
	gluon-mesh-vpn-l2tp \
	gluon-respondd \
	gluon-autoupdater \
	gluon-config-mode-core \
	gluon-config-mode-autoupdater \
	gluon-config-mode-mesh-vpn \
	gluon-config-mode-geo-location \
	gluon-config-mode-contact-info \
	gluon-status-page \
	gluon-web-admin \
	gluon-web-network \
	gluon-web-wifi-config \
	gluon-ebtables-filter-multicast \
	gluon-ebtables-filter-ra-dhcp \
	gluon-ebtables-source-filter \
	iwinfo \
	iptables \
	haveged

## Mindest-Firmware-Version für Autoupdater-Akzeptanz
## (Knoten mit älterer Version werden ebenfalls aktualisiert)
GLUON_RELEASE := 2023.2.5+ffhat1

## Autoupdater: Prozentsatz der Knoten, die pro Tag updaten (Rollout-Kontrolle)
GLUON_PRIORITY := 0

## Targets, die mit diesem site.mk gebaut werden
## ath79-generic: TP-Link, Ubiquiti u.a. (Primär-Target)
## x86-64: VM-Tests, x86-basierte Router
##
## Aktivierung: make GLUON_TARGET=ath79-generic GLUON_SITEDIR=../site
## Weitere Targets (ramips-mt7621 etc.) sind für v2 vorgesehen.
