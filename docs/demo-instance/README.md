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

Am einfachsten das Repository klonen — Home Assistant legt seine Laufzeitdaten
unter `config/` an, und die sind über die `.gitignore` bereits ausgeschlossen:

```bash
cd /opt
git clone --depth 1 https://github.com/jan620/HA-Apple-TV.git
cd HA-Apple-TV/docs/demo-instance
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

> **WebSocket** braucht keine Einstellung, Caddy reicht Upgrade-Anfragen von
> selbst durch. Die Weiterleitungs-Kopfzeilen entfernt Caddy dagegen bewusst —
> die Begründung steht im `Caddyfile`.

## 5 · Einrichten lassen statt klicken

`seed_demo.py` erledigt Bereiche, Zuordnung, Dashboard und Energie-Dashboard in
einem Durchlauf. Es liest die Entitäten aus der laufenden Instanz, rät also
keine Namen und funktioniert auch, wenn eine neuere Home-Assistant-Fassung
andere Demo-Entitäten mitbringt.

Zuerst einen Token holen: **Profil → Sicherheit → Langlebige Zugangstoken →
Token erstellen**. Er wird genau einmal angezeigt.

```bash
docker compose cp seed_demo.py homeassistant:/tmp/seed_demo.py
docker compose exec homeassistant python /tmp/seed_demo.py --token <TOKEN>
```

Der Aufruf läuft im Container, weil dort `aiohttp` schon vorhanden ist — auf
dem Server müsste es erst installiert werden.

Das Skript ist wiederholbar: vorhandene Bereiche werden erkannt, bereits
zugeordnete Entitäten bleiben unangetastet.

Was es anlegt:

- **Bereiche** Wohnzimmer, Küche, Schlafzimmer, Büro
- **Zuordnung** je Domäne reihum, damit jeder Raum etwas Sichtbares hat und
  nicht alle Lampen im Wohnzimmer landen
- **Dashboard** „Demo" mit `entities`-, `thermostat`-, `weather-forecast`- und
  Rollladen-Karte — genau die Typen, die Roomglance nativ zeichnet
- **Energie-Dashboard** mit dem ersten Sensor, der `device_class: energy` und
  eine aufsummierende `state_class` hat

Danach in der Oberfläche kurz durchsehen und bei Bedarf nachjustieren.

> **Die Statistiken entstehen erst im Betrieb.** Die Instanz also lieber einen
> Tag vor der Einreichung aufsetzen als eine Stunde — sonst bleiben die
> Energie-Diagramme leer. Ohne Energie-Dashboard blendet die App den Bereich
> aus; das ist kein Fehler, aber ein Teil der App bleibt der Prüfung verborgen.

## 6 · Von Hand, falls das Skript nicht durchläuft

**Einstellungen → Bereiche, Labels & Zonen → Bereich erstellen** — vier
genügen. Danach unter **Einstellungen → Geräte & Dienste → Entitäten** die
Demo-Entitäten verteilen; Mehrfachauswahl über die Checkboxen, dann *Bereich
zuweisen*. In jedem Bereich sollte etwas Sichtbares landen, am besten ein
Thermostat.

**Einstellungen → Dashboards → Dashboard hinzufügen** — eine `entities`-Karte,
eine `thermostat`-Karte, eine `weather-forecast`-Karte.

**Einstellungen → Dashboards → Energie** — einen Demo-Verbrauchssensor als
Netzbezug.

## 7 · Von unterwegs testen

Adresse im Mobilfunknetz aufrufen, anmelden, und einmal mit der App verbinden.
Klappt das nicht, klappt es bei Apple auch nicht.

## 8 · In die App Review Notes eintragen

Der fertige Text steht in `../app-store-listing.md` unter *App Review Notes*.
Einzusetzen sind nur Adresse, Benutzername und Passwort.

## 9 · Nach der Freigabe

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
