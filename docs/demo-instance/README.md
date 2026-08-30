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

---

## 1 · Starten

```bash
docker compose -f docs/demo-instance/docker-compose.yml up -d
```

Läuft auf Port **8124**, damit es der produktiven Instanz auf 8123 nicht in die
Quere kommt. Der erste Start dauert ein bis zwei Minuten.

Dann `http://<host>:8124` öffnen und den Einrichtungsassistenten durchlaufen.
Das dabei angelegte Konto ist Administrator — genau das braucht die Prüfung.

Benutzername und Passwort so wählen, dass sie sich in die App Review Notes
schreiben lassen; etwas wie `appreview` / ein zufälliges Passwort. Es sind
Wegwerf-Zugangsdaten für eine Instanz ohne echte Daten.

## 2 · Bereiche anlegen

**Einstellungen → Bereiche, Labels & Zonen → Bereich erstellen**

Drei bis vier genügen: Wohnzimmer, Küche, Schlafzimmer, Büro. Danach unter
**Einstellungen → Geräte & Dienste → Entitäten** die Demo-Entitäten auf die
Bereiche verteilen — Mehrfachauswahl über die Checkboxen, dann *Bereich
zuweisen*.

Ohne diesen Schritt bleibt die Räume-Ansicht der App leer, und das ist einer
der beiden Modi, die im Onboarding zur Wahl stehen.

## 3 · Ein Dashboard anlegen

**Einstellungen → Dashboards → Dashboard hinzufügen**

Ein paar Karten reichen: eine `entities`-Karte, eine `thermostat`-Karte, eine
`weather-forecast`-Karte. Damit ist die Dashboard-Auswahl im Onboarding nicht
leer und der native Kartenrenderer hat etwas zu zeigen.

## 4 · Energie-Dashboard (optional, aber empfohlen)

**Einstellungen → Dashboards → Energie**

Als Netzverbrauch einen der Demo-Verbrauchssensoren eintragen. Nach ein paar
Stunden Laufzeit stehen genug Statistiken für die Diagramme bereit — die
Instanz also lieber einen Tag vor der Einreichung starten als eine Stunde.

Ohne Energie-Dashboard blendet die App den Bereich aus. Das ist kein Fehler,
aber ein Teil der App bleibt der Prüfung dann verborgen.

## 5 · Von außen erreichbar machen

Die App-Prüfung sitzt nicht in Deutschland; eine Adresse im Heimnetz nützt
nichts. Zwei Wege:

**Nabu Casa** — in der Demo-Instanz unter *Einstellungen → Home Assistant Cloud*
anmelden. 31 Tage kostenlos, liefert sofort eine erreichbare HTTPS-Adresse.
Die Frist läuft ab Aktivierung, also erst starten, wenn die Einreichung
ansteht.

**Cloudflare Tunnel** — kostenlos und ohne Frist, dafür etwas Einrichtung:

```bash
cloudflared tunnel --url http://localhost:8124
```

Gibt eine zufällige `trycloudflare.com`-Adresse aus, die nur läuft, solange der
Befehl läuft. Für eine stabile Adresse einen benannten Tunnel auf eine eigene
Subdomain einrichten.

**Danach unbedingt aus einem fremden Netz testen** — am einfachsten über das
Mobilfunknetz des Telefons. Adresse aufrufen, anmelden, und einmal mit der App
verbinden.

## 6 · In die App Review Notes eintragen

Der fertige Text steht in `../app-store-listing.md` unter *App Review Notes*.
Einzusetzen sind nur Adresse, Benutzername und Passwort.

## 7 · Nach der Freigabe

```bash
docker compose -f docs/demo-instance/docker-compose.yml down
```

**Vor jedem Update wieder hochfahren** — jede neue Version wird erneut geprüft,
und eine tote Adresse in den Review Notes führt zuverlässig zur Ablehnung. Das
`config`-Verzeichnis bleibt bestehen, der Neustart ist also ein Einzeiler.

---

## Was hier nicht liegt

Das `config`-Verzeichnis enthält nur `configuration.yaml`. Alles andere legt
Home Assistant beim ersten Start selbst an — darunter `.storage` mit Benutzern
und Zugangsdaten. **Diese Dateien gehören nicht ins Repository**; sie sind über
die `.gitignore` im Projekt ausgeschlossen.
