# HA-Apple-TV

Eine native **Home Assistant App für Apple TV** (tvOS 17+, SwiftUI).

Die App meldet sich per OAuth/IndieAuth an deiner Instanz an, verbindet sich über
die WebSocket-API und **rendert deine echten Lovelace-Dashboards nativ** — mit
fernbedienungstauglicher Steuerung für Licht, Klima, Rollläden, Medien und
Kameras.

---

## Warum nativ und nicht wie die iOS-App?

Die offizielle iOS-App zeigt Lovelace in einer `WKWebView` an. **tvOS enthält kein
WebKit** — es gibt auf dem Apple TV schlicht keine Web-Engine, die man einbetten
könnte. Deshalb geht diese App einen anderen Weg:

1. Sie lädt deine **echte Dashboard-Konfiguration** über `lovelace/config`.
2. Sie übersetzt jede Karte in eine **native SwiftUI-View**.
3. Alles ist live: Zustände kommen über `subscribe_events` herein, Aktionen gehen
   als `call_service` hinaus.

Das Ergebnis sieht aus wie deine Dashboards, fühlt sich aber wie eine tvOS-App
an — inklusive Fokus-Effekten, die man aus 3 Metern Entfernung bedienen kann.

---

## Bauen und installieren

Voraussetzung: ein Mac mit Xcode 15 oder neuer.

```bash
git clone <dieses-repo>
cd HA-Apple-TV
python3 Tools/generate_xcodeproj.py
open HomeAssistantTV.xcodeproj
```

Dann in Xcode das Signing-Team setzen (Target → *Signing & Capabilities*) und auf
den Apple TV Simulator oder dein Gerät bauen.

> Die `.xcodeproj` wird generiert und ist mit eingecheckt. Nach dem Hinzufügen
> oder Löschen von Swift-Dateien einfach `python3 Tools/generate_xcodeproj.py`
> erneut ausführen — die IDs sind deterministisch, der Diff bleibt minimal.
> `--check` prüft die Struktur, ohne etwas zu schreiben.

**App-Icon:** Das Projekt setzt bewusst kein `ASSETCATALOG_COMPILER_APPICON_NAME`,
damit es ohne die vielschichtigen tvOS-Icon-Assets sofort baut. Für eine
Veröffentlichung musst du in `Resources/Assets.xcassets` ein
*App Icon & Top Shelf Image*-Set anlegen und die Build-Einstellung ergänzen.

---

## Anmeldung

Beim ersten Start:

1. **Server wählen** — Instanzen im Heimnetz werden per Bonjour
   (`_home-assistant._tcp`) automatisch gefunden; alternativ die Adresse manuell
   eingeben (`homeassistant.local:8123`, `192.168.1.10:8123`,
   `https://xyz.ui.nabu.casa`).
2. **Anmelden** — Benutzername und Passwort, bei Bedarf gefolgt von der
   Zwei-Faktor-Abfrage.

Technisch läuft das über Home Assistants eigenen Login-Flow
(`/auth/login_flow` → `/auth/token`), also denselben Authorization-Code-Grant wie
im Browser — nur ohne Web-Ansicht, weil die Anmeldemaske aus den vom Server
gelieferten Schritt-Beschreibungen nativ aufgebaut wird. Damit funktionieren auch
MFA-Provider ohne Sonderbehandlung.

Der **Refresh Token** liegt im Keychain, der Access Token wird bei Bedarf
automatisch erneuert. Beim Abmelden wird er serverseitig widerrufen.

Als `client_id` und `redirect_uri` dient die Basis-URL deiner Instanz. Weil beide
dieselbe Origin haben, überspringt Home Assistant die IndieAuth-Prüfung per
Netzwerkabruf — so klappt die Anmeldung auch bei Instanzen, die nur über eine
lokale IP erreichbar sind.

---

## Unterstützte Lovelace-Karten

| Karte | Status |
|---|---|
| `entities`, `glance`, `tile`, `button`, `entity` | ✅ inkl. Zeilentypen `divider` / `section` / `attribute` |
| `grid`, `vertical-stack`, `horizontal-stack`, `conditional` | ✅ inkl. Bedingungen `state`, `numeric_state`, `and`/`or`/`not` |
| `light`, `thermostat`, `humidifier`, `media-control` | ✅ mit Bedienelementen |
| `weather-forecast` | ✅ inkl. Vorhersage über `weather/subscribe_forecast` |
| `picture-entity`, `picture-glance`, `picture` | ✅ inkl. Kamera-Standbildern |
| `gauge` | ✅ |
| `markdown` | ✅ Templates werden serverseitig via `render_template` gerendert |
| `history-graph` | ✅ numerische Verläufe (Swift Charts) |
| `alarm-panel` | ⚠️ ohne Code-Eingabe |
| `area`, `heading` | ✅ |
| `iframe`, `custom:*` | ❌ benötigen eine Web-Engine |
| `map`, `logbook`, `todo-list`, `statistics-graph`, Energie-Karten | ❌ noch nicht umgesetzt |

Nennt eine nicht unterstützte Karte eine Entität, zeigt die App deren Zustand
statt eines Platzhalters — und rendert ein Attribut, das eine Liste
gleichförmiger Objekte enthält, als Tabelle. Damit bleiben Custom Cards wie
Abfahrtsmonitore oder Flugtracker brauchbar, obwohl ihr JavaScript nicht läuft.
Karten ohne Entitätsbezug erscheinen als beschrifteter Platzhalter.

**Ansichtstypen:** `masonry` (Standard), `sections`, `panel` und `sidebar` werden
in ein TV-taugliches Spaltenraster übersetzt. Unteransichten (`subview: true`)
sind über Navigations-Aktionen erreichbar, tauchen aber nicht in der Tab-Leiste
auf — genau wie im Web-Frontend.

### Strategie-Dashboards

Dashboards, die per **Strategie** erzeugt werden (dazu gehört die unveränderte
Standard-Übersicht), sind JavaScript, das im Browser läuft. Statt einer leeren
Seite baut die App dann selbst eine Ansicht: **eine Ansicht pro Bereich**,
Steuerungen nach Domäne gruppiert, Sensoren in einer Liste — analog zu Home
Assistants „original-states“-Strategie. In den Einstellungen wird angezeigt, wenn
eine Ansicht so entstanden ist.

---

## Bedienung mit der Siri Remote

| Eingabe | Wirkung |
|---|---|
| **Auswählen** | führt die `tap_action` der Karte aus (Standard: schaltbare Entitäten umschalten, sonst Details öffnen) |
| **Play/Pause** | öffnet auf jeder Kachel die **Detailansicht** |
| **Links/Rechts** auf einem Regler | ändert den Wert (wird nach kurzer Pause gesendet) |
| **Menü** | schließt die Detailansicht |

---

### Energie-Dashboard

Das Energie-Dashboard ist **kein Lovelace-Dashboard**: Home Assistant
registriert es als eingebautes Panel, das der Browser per Strategie aus
energiespezifischen Karten zusammensetzt. Es taucht deshalb nicht in
`lovelace/dashboards/list` auf. Die App baut es aus den Langzeit-Statistiken
nach (`energy/get_prefs`, `energy/info`,
`recorder/statistics_during_period`) und zeigt Verbrauch, Netzbezug,
Einspeisung, Solar, Batterie, Gas, Wasser, Autarkie und **Kosten** — umschaltbar
zwischen Heute, Gestern, 7 Tagen und Monat, dazu ein Verlaufsdiagramm und die
größten Verbraucher.

Kosten werden aus den konfigurierten Kosten-Statistiken gelesen. Ist im
Energie-Setup nur ein Preis hinterlegt, erzeugt Home Assistant den Kosten-Sensor
selbst und schreibt ihn *nicht* in die Einstellungen zurück — die Zuordnung
kommt dann aus `energy/info`. Beide Wege werden unterstützt.

Nicht umgesetzt: die Sankey-artige Energieverteilung des Originals und die
Verschachtelung der Gerätewerte über `included_in_stat`.

## Onboarding

Nach dem ersten Login fragt die App, was auf dem Fernseher erscheinen soll:
**Räume, Dashboards oder beides**. Bei Dashboards lassen sich die vorhandenen
Lovelace-Dashboards einzeln auswählen (das Energie-Panel erscheint dort als
eigener Eintrag), bei Räumen die Bereiche. Alles ist vorausgewählt — wer
durchklickt, bekommt das vollständige Bild.

Die Auswahl liegt in `UserDefaults` und lässt sich über **Ansicht neu
einrichten** im Dashboards-Tab jederzeit wiederholen.

## Was die App sonst kann

- **Kameras**: Live-Stream über `camera/stream` (HLS via `AVPlayer`), mit
  automatischem Rückfall auf Standbild-Polling für Kameras ohne
  `stream`-Integration.
- **Steuerung** in den Detailansichten: Licht (Helligkeit, Farbtemperatur,
  Effekte), Klima (Solltemperatur, Betriebsart, Voreinstellung), Rollläden und
  Ventile (auf/stopp/zu, Position, Lamellen), Medien (Transport, Lautstärke,
  Quelle), Lüfter, Schlösser, Staubsauger, `select`- und `number`-Helfer.
- **Automatischer Reconnect** mit exponentiellem Backoff; ein Banner zeigt den
  Verbindungszustand.
- **Mehrere Dashboards** über die Einstellungen umschaltbar.

---

## Netzwerk-Hinweise

- `NSAllowsLocalNetworking` ist gesetzt, damit **HTTP im Heimnetz** funktioniert
  (`.local`-Namen und private IP-Bereiche). Eine über **HTTP auf einem
  öffentlichen Hostnamen** erreichbare Instanz bräuchte zusätzlich
  `NSAllowsArbitraryLoads` — das ist bewusst nicht gesetzt.
- Für **selbstsignierte TLS-Zertifikate** gibt es im Setup einen expliziten
  Schalter. Er gilt nur für den eingerichteten Server.
- tvOS fragt beim ersten Start nach der Freigabe für das **lokale Netzwerk**.
  Ohne diese Freigabe funktionieren weder Bonjour-Suche noch LAN-Verbindungen.

---

## Bekannte Grenzen

- Der Code entstand ohne Zugriff auf einen Mac. Er baut inzwischen fehlerfrei
  gegen das tvOS-SDK und läuft im Simulator gegen eine echte Instanz, ist aber
  nicht systematisch getestet.
- **Nicht-Admin-Accounts** bekommen von Home Assistant keinen Zugriff auf die
  Registries. Die App funktioniert weiter, kann Entitäten dann aber nicht nach
  Bereichen gruppieren (betrifft nur automatisch erzeugte Ansichten).
- Der `EntityStore` veröffentlicht bei jeder Zustandsänderung; bei sehr großen
  Instanzen mit hoher Update-Rate wäre eine Bündelung sinnvoll.
- MDI-Icons sind auf SF Symbols abgebildet. Die gängigen Icons sind abgedeckt,
  seltenere fallen auf ein Domänen-Symbol zurück.

---

## Projektstruktur

```
Sources/
  App/          App-Einstieg, Objektgraph, Root-Navigation
  Auth/         Login-Flow, Token-Verwaltung, Bonjour-Suche, Setup-UI
  Network/      WebSocket-Client (Auth-Handshake, Requests, Events, Reconnect)
  Model/        Entitäten, Registries, EntityStore, Service-Aufrufe
  Lovelace/     Dashboard-Modelle, Config-Laden, View- und Karten-Renderer
  MoreInfo/     Detailansichten je Domäne
  Support/      Bild-Laden, Template-/Forecast-/History-Subscriptions
  UI/           Theme, Fokus-Bedienelemente, MDI→SF-Symbols-Mapping
  Core/         JSON-Werttyp, Keychain
Resources/      Info.plist, Asset-Katalog
Tools/          Generator für die .xcodeproj
```
