# Bis in den App Store — Abhakliste

Stand: 30. August 2026. Reihenfolge ist nicht beliebig: 1 und 2 dauern in der
Wartezeit am längsten und blockieren den Rest.

---

## Schon erledigt

- [x] Apple Developer Program
- [x] Repository öffentlich
- [x] GitHub Pages aktiv, Datenschutzerklärung erreichbar unter
      <https://jan620.github.io/HA-Apple-TV/>
- [x] Name geklärt und überall eingetragen: **Roomglance**
      (HomeDash war im App Store vergeben)
- [x] Bundle-ID festgelegt: `io.roomglance.tvos`
- [x] Ko-fi- und Sponsors-Handles
- [x] App-Icon, Top-Shelf-Bilder, Privacy Manifest, Exporterklärung
- [x] Store-Texte, App Review Notes, Nutrition-Label-Antworten vorbereitet
- [x] Zwei Sicherheits-Reviews, Befunde behoben
- [x] Marken-Fallstricke ausgeräumt (Name, Icon, Einrichtungsbildschirm)
- [x] Baut fehlerfrei in Xcode

---

## 1 · App-Eintrag anlegen — sichert den Namen

Namen sind exklusiv und werden nach Anmeldezeitpunkt vergeben. Zuerst, noch
bevor irgendetwas fertig ist.

- [x] Falls nötig, App-ID anlegen: developer.apple.com →
      *Certificates, Identifiers & Profiles → Identifiers → +* → *App IDs* →
      Plattform tvOS → `io.roomglance.tvos`
- [x] App Store Connect → *Apps → + → Neue App*
- [x] Plattform **tvOS**, Name **Roomglance**, Primärsprache **Deutsch**
- [x] Bundle-ID `io.roomglance.tvos`, SKU `roomglance-tvos`

> Meldet Apple den Namen als vergeben: **nicht** improvisieren, sondern melden —
> dann suchen wir eine geprüfte Alternative statt einer, die später Ärger macht.

## 2 · Demo-Instanz aufsetzen

Der häufigste Ablehnungsgrund für Apps zu selbstgehosteten Diensten. Alles
Nötige liegt fertig unter [`demo-instance/`](demo-instance/README.md).

- [ ] `docker compose -f docs/demo-instance/docker-compose.yml up -d`
- [ ] `http://<host>:8124` öffnen, Assistenten durchlaufen,
      **Administrator-Konto** anlegen (z. B. `appreview`)
- [ ] Drei bis vier **Bereiche** anlegen und Demo-Entitäten zuordnen
- [ ] Ein **Dashboard** mit ein paar Karten anlegen
- [ ] **Energie-Dashboard** einrichten — mindestens einen Tag vor der
      Einreichung, sonst fehlen die Statistiken
- [ ] Von außen erreichbar machen (Nabu Casa oder Cloudflare Tunnel)
- [ ] **Aus einem fremden Netz testen**, am einfachsten über Mobilfunk
- [ ] Adresse, Benutzername und Passwort notieren — kommen in Schritt 7

## 3 · Signing dauerhaft einrichten

Ohne das schreibt Xcode die Team-ID immer wieder in die generierte
Projektdatei, und jeder `git pull` kollidiert.

- [ ] `grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' Roomglance.xcodeproj/project.pbxproj`
- [ ] `echo DEINE-TEAM-ID > Tools/development-team.txt`
- [ ] `python3 Tools/generate_xcodeproj.py`
- [ ] Kontrolle: `grep -c DEVELOPMENT_TEAM Roomglance.xcodeproj/project.pbxproj`
      muss **4** ergeben

## 4 · Prüfen

- [x] **⌘U** — Testtarget läuft im Simulator fehlerfrei durch. Der erste Lauf
      hat einen echten Fehler in `HAServer.normalizedURL` gefunden (PR #14)
- [ ] Auf dem **echten Apple TV**: Anmeldung, Onboarding, ein Dashboard, die
      Räume-Ansicht, das Energie-Dashboard
- [ ] Zurück-Taste an mehreren Stellen — muss ins Menü führen, nicht aus der App
- [ ] Bildschirmschoner über *Jetzt anzeigen*, einmal mit Hintergrundbildern

## 5 · Screenshots

Mindestens einer in **1920 × 1080**. Simulator: ⌘S. Gerät: Xcode →
*Window → Devices and Simulators → Take Screenshot*.

- [ ] Ein Dashboard mit Karten
- [ ] Die Räume-Ansicht
- [ ] Das Energie-Dashboard mit dem Sankey-Diagramm
- [ ] Der Bildschirmschoner mit Hintergrundbild
- [ ] Eine Detailansicht (Lampe oder Klimaanlage)

> Räume wählen, in denen alles verfügbar ist — rote „Nicht verfügbar"-Zeilen
> verkaufen die App schlecht. Und das Home-Assistant-Logo nie als Hauptmotiv.

## 6 · Bauen und hochladen

- [ ] `git pull && python3 Tools/generate_xcodeproj.py`
- [ ] Ziel auf **Any tvOS Device (arm64)** stellen — sonst ist *Archive*
      ausgegraut
- [ ] *Product → Archive*
- [ ] Organizer → *Distribute App → App Store Connect → Upload*
- [ ] Warten, bis der Build unter *TestFlight* auftaucht (Minuten bis Stunde)

> Version und Build stehen auf `1.0` / `1`. Jeder weitere Upload braucht eine
> höhere `CFBundleVersion` in `Resources/Info.plist`.

## 7 · TestFlight

Optional, fängt aber die Fehler ab, die sonst eine Ablehnung und eine
Wartewoche kosten. Interne Tests brauchen keine Beta-Prüfung.

- [ ] *TestFlight → Interne Tests*, Gruppe anlegen, sich selbst hinzufügen
- [ ] Auf dem Apple TV über TestFlight installieren
- [ ] Kompletten Ablauf einmal durchgehen

## 8 · Store-Eintrag ausfüllen

Alle Texte fertig in [`app-store-listing.md`](app-store-listing.md).

- [x] Name, Untertitel, Werbetext, Beschreibung, Keywords übernehmen —
      **den Markenhinweis am Ende der Beschreibung nicht kürzen**
- [ ] Screenshots hochladen — braucht die laufende Demo-Instanz, siehe Schritt 5
- [x] Support-URL `https://github.com/jan620/HA-Apple-TV`
- [x] Datenschutz-URL `https://jan620.github.io/HA-Apple-TV/`
- [x] Kategorie *Dienstprogramme*, sekundär *Lifestyle*
- [x] Altersfreigabe: alle Fragen mit Nein → ergibt 4+
- [x] Copyright `2026 Yoga Ananthapavan Yogananthar`

## 9 · Datenschutz und Händlerstatus

Begründungen in [`app-store-privacy.md`](app-store-privacy.md).

- [x] *App-Datenschutz*: „Erfasst diese App Daten?" → **Nein**
- [ ] Tracking über Apps und Websites hinweg → **Nein**. Sachlich eindeutig:
      keine einzige Fremdabhängigkeit, kein Analyse-SDK, keine IDFA-Abfrage —
      die App importiert ausschließlich Apple-Systemframeworks
- [ ] **Händlerstatus (DSA)** unter *Business → Compliance* — die Erklärung ist
      Pflicht, beide Antworten sind zulässig. Ohne In-App-Käufe ist
      „kein Händler" vertretbar; dann veröffentlicht Apple deine Anschrift nicht

> Die Exportfrage entfällt, `ITSAppUsesNonExemptEncryption` steht schon im
> Info.plist.

## 10 · Einreichen

- [ ] Build auswählen
- [ ] **App Review Notes** ausfüllen — Text aus `app-store-listing.md`, nur
      Adresse und Zugangsdaten der Demo-Instanz einsetzen.
      **Ohne diesen Text wird die App abgelehnt**
- [ ] Kontaktdaten für Rückfragen
- [ ] Freigabe auf *manuell* stellen
- [ ] Zur Prüfung einreichen

> Dauert erfahrungsgemäß ein bis drei Tage. Bei einer Ablehnung antwortet man im
> *Resolution Center*; oft genügt eine Erklärung ohne neuen Build.

## 11 · Nach der Freigabe

- [ ] Demo-Instanz abschalten —
      **vor jedem Update wieder hoch**, jede Version wird neu geprüft
- [ ] Release-Tag setzen:
      `git tag -a v1.0 -m "Erste Veröffentlichung" && git push origin v1.0`
- [ ] Im README auf den App Store verlinken
