# Demo-Instanz für die App-Prüfung

Apple prüft die App auf einem eigenen Gerät. Roomglance ist ein Client ohne
eigene Serverkomponente — ohne erreichbare Home-Assistant-Instanz sieht die
Prüfung nur den Einrichtungsbildschirm und lehnt die App als unvollständig ab
(Richtlinie 2.1). Diese Instanz ist die Antwort darauf.

**Nicht die produktive Instanz verwenden.** Home Assistant kennt keine
Berechtigungen je Entität: Auch ein Konto ohne Administratorrechte sieht
sämtliche Entitäten — Kameras, Anwesenheit der Haushaltsmitglieder, Schlösser —
und kann alles schalten. Ohne Administratorrechte wiederum gibt Home Assistant
die Bereichsliste nicht heraus, wodurch die App funktionsärmer wirkt, als sie
ist. Ein Konto „mit wenigen Berechtigungen" lässt sich nicht anlegen.

**Warum ein eigener Server und nicht die NAS.** Die Prüfung sitzt nicht in
Deutschland, die Instanz muss also aus dem Internet erreichbar sein. Über einen
Reverse Proxy auf der NAS ist das erfahrungsgemäß mühsam — DSM reicht
WebSocket-Upgrades nicht ohne Zusatzkonfiguration durch, und Home Assistant
lehnt weitergereichte Anfragen ohne `trusted_proxies` mit `400` ab. Ein kleiner
Mietserver kostet ein paar Euro, ist in zwanzig Minuten eingerichtet, hält die
Angriffsfläche von der NAS fern und lässt sich nach der Freigabe wieder
löschen.

---

## 1 · Server anlegen

Bei Hetzner Cloud ein Projekt öffnen und einen Server erstellen:

| | |
|---|---|
| Standort | Nürnberg oder Falkenstein |
| Abbild | Ubuntu 24.04 |
| Typ | **CX22** (2 vCPU, 4 GB) — reicht für die Demo mit Reserve |
| Netzwerk | IPv4 **und** IPv6 |
| SSH-Schlüssel | den eigenen hinterlegen |

Dazu eine **Firewall** anlegen und dem Server zuweisen. Eingehend nur:

- **22/tcp** (SSH)
- **80/tcp** (Zertifikatsprüfung von Let's Encrypt)
- **443/tcp** (die App und die Oberfläche)

Alles andere bleibt zu. Port 8123 wird nach außen nie geöffnet — Home Assistant
ist ausschließlich über Caddy erreichbar.

## 2 · DNS setzen

Einen A-Eintrag auf die IPv4-Adresse des Servers legen, zum Beispiel
`hademo.deine-domain.de`. Bei IPv6 zusätzlich einen AAAA-Eintrag.

**Das muss vor Schritt 4 stehen.** Caddy holt das Zertifikat beim ersten Start;
zeigt der Name noch nicht auf den Server, schlägt das fehl und Caddy wartet vor
dem nächsten Versuch.

Prüfen lässt es sich mit:

```bash
dig +short hademo.deine-domain.de
```

## 3 · Docker installieren

```bash
ssh root@<server-ip>
curl -fsSL https://get.docker.com | sh
```

## 4 · Instanz starten

Die drei Dateien aus diesem Verzeichnis auf den Server legen —
`docker-compose.yml`, `Caddyfile` und `config/configuration.yaml`:

```bash
mkdir -p /opt/ha-demo
cd /opt/ha-demo
# Dateien hierher kopieren, z. B. mit scp oder git clone
cp .env.example .env
nano .env          # DEMO_DOMAIN eintragen
docker compose up -d
```

Der erste Start dauert ein bis zwei Minuten. Caddy holt das Zertifikat
selbstständig; im Log ist zu sehen, ob es geklappt hat:

```bash
docker compose logs caddy | grep -i certificate
```

Dann `https://hademo.deine-domain.de` öffnen und den Einrichtungsassistenten
durchlaufen. Das dabei angelegte Konto ist Administrator — genau das braucht
die Prüfung.

Benutzername und Passwort so wählen, dass sie sich in die App Review Notes
schreiben lassen; etwa `appreview` und ein zufälliges Passwort. Es sind
Wegwerf-Zugangsdaten für eine Instanz ohne echte Daten.

> **WebSocket** braucht keine Einstellung. Caddy reicht Upgrade-Anfragen von
> selbst durch, und `trusted_proxies` in der `configuration.yaml` deckt das
> Compose-Netz bereits ab.

## 5 · Bereiche anlegen

**Einstellungen → Bereiche, Labels & Zonen → Bereich erstellen**

Vier genügen: Wohnzimmer, Küche, Schlafzimmer, Büro. Danach unter
**Einstellungen → Geräte & Dienste → Entitäten** die Demo-Entitäten auf die
Bereiche verteilen — Mehrfachauswahl über die Checkboxen, dann *Bereich
zuweisen*.

Darauf achten, dass in jedem Bereich etwas Sichtbares landet: eine Lampe, ein
Sensor, am besten ein Thermostat. Ohne diesen Schritt bleibt die Räume-Ansicht
leer, und das ist einer der beiden Modi, die im Onboarding zur Wahl stehen.

## 6 · Ein Dashboard anlegen

**Einstellungen → Dashboards → Dashboard hinzufügen**

Drei Karten reichen und decken ab, was Roomglance nativ zeichnet:

- eine `entities`-Karte mit ein paar Lampen und Sensoren
- eine `thermostat`-Karte
- eine `weather-forecast`-Karte

## 7 · Energie-Dashboard

**Einstellungen → Dashboards → Energie**

Als Netzverbrauch einen der Demo-Verbrauchssensoren eintragen. Die Statistiken
entstehen erst im Betrieb — **die Instanz also lieber einen Tag vor der
Einreichung starten als eine Stunde.** Ohne Energie-Dashboard blendet die App
den Bereich aus; das ist kein Fehler, aber ein Teil der App bleibt der Prüfung
dann verborgen.

## 8 · Von unterwegs testen

Adresse im Mobilfunknetz aufrufen, anmelden, und einmal mit der App verbinden.
Klappt das nicht, klappt es bei Apple auch nicht.

## 9 · In die App Review Notes eintragen

Der fertige Text steht in `../app-store-listing.md` unter *App Review Notes*.
Einzusetzen sind nur Adresse, Benutzername und Passwort.

## 10 · Nach der Freigabe

Den Server bei Hetzner löschen — oder, wenn er für das nächste Update stehen
bleiben soll, wenigstens vom Netz nehmen.

**Vor jedem Update wieder hochfahren.** Jede neue Version wird erneut geprüft,
und eine tote Adresse in den Review Notes führt zuverlässig zur Ablehnung.

---

## Was hier nicht liegt

Das `config`-Verzeichnis enthält nur `configuration.yaml`. Alles andere legt
Home Assistant beim ersten Start selbst an — darunter `.storage` mit Benutzern
und Zugangsdaten. **Diese Dateien gehören nicht ins Repository**; sie sind über
die `.gitignore` im Projekt ausgeschlossen. Ebenso die `.env` mit dem
Domainnamen.
