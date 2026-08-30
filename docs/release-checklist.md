# Schritt für Schritt in den App Store

Ab dem Punkt, an dem das Apple Developer Program bereits vorhanden ist. Die
Reihenfolge ist bewusst gewählt: Schritt 2 und 3 dauern in der Wartezeit am
längsten, deshalb stehen sie vorn. Schritt 6 ist der, an dem Apps zu
selbstgehosteten Diensten üblicherweise scheitern.

---

## 1 · Repository öffentlich stellen und Datenschutzerklärung ausliefern

Apple verlangt bei der Einreichung eine öffentlich erreichbare URL zur
Datenschutzerklärung. Der Text ist fertig, ihm fehlt nur die Adresse.

1. `https://github.com/jan620/HA-Apple-TV` öffnen
2. **Settings → General**, ganz nach unten zur *Danger Zone*
3. **Change visibility → Change to public**, Bestätigung eintippen
4. **Settings → Pages**, unter *Build and deployment* die Quelle auf
   **GitHub Actions** stellen. **Dieser Schritt ist unvermeidbar** — der
   Workflow kann Pages nicht selbst einschalten, weil das Anlegen einer
   Pages-Site Administratorrechte verlangt, die das `GITHUB_TOKEN` einer
   Action nicht hat. Ohne ihn scheitert jeder Lauf an `configure-pages`.
5. **Actions** öffnen, den Workflow *Datenschutzerklärung veröffentlichen*
   auswählen, **Run workflow** → Branch `main`
6. Nach etwa einer Minute prüfen: **https://jan620.github.io/HA-Apple-TV/**

Diese URL kommt später in App Store Connect ins Feld *Privacy Policy URL*.
Als *Support URL* genügt `https://github.com/jan620/HA-Apple-TV`.

## 2 · App-Eintrag anlegen und den Namen sichern

Namen im App Store sind exklusiv und werden nach Anmeldezeitpunkt vergeben.
Deshalb sofort, noch bevor irgendetwas fertig ist.

1. **App Store Connect → Apps → +  → Neue App**
2. Plattform **tvOS**, Name **HomeDash**, Primärsprache **Deutsch**
3. **Bundle-ID**: `io.github.jan620.homedash` aus der Liste wählen. Steht sie
   nicht darin, vorher unter
   *developer.apple.com → Certificates, Identifiers & Profiles → Identifiers*
   anlegen — Typ *App IDs*, Plattform *tvOS*
4. **SKU**: frei wählbar, erscheint nirgends öffentlich, z. B. `homedash-tvos`
5. Zugriff auf **Vollzugriff** lassen

Meldet Apple den Namen als vergeben, hilft ein Zusatz wie *HomeDash for Home
Assistant* — Vorsicht: Der Markenname darf **nicht** in den App-Namen, siehe
`app-store-listing.md`. Dann eher *HomeDash Smart Home*.

## 3 · Signing einrichten

1. Team-ID herausfinden (Xcode → *Settings → Accounts → Konto auswählen*) oder,
   falls schon einmal für ein Gerät signiert wurde:

   ```bash
   grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' HomeDash.xcodeproj/project.pbxproj
   ```

2. Lokal hinterlegen, damit sie das Neuerzeugen des Projekts übersteht:

   ```bash
   echo DEINE-TEAM-ID > Tools/development-team.txt
   python3 Tools/generate_xcodeproj.py
   ```

3. In Xcode prüfen: Target *HomeDash* → *Signing & Capabilities* → Team steht,
   *Automatically manage signing* ist aktiv, keine Fehlermeldung.

Mit einem bezahlten Account entfällt die Sieben-Tage-Grenze der kostenlosen
Signierung; die App bleibt auf dem Apple TV lauffähig.

## 4 · Demo-Instanz für die App-Prüfung

**Nicht die produktive Instanz verwenden.** Home Assistant kennt keine
Berechtigungen je Entität — auch ein Konto ohne Administratorrechte sieht
sämtliche Entitäten, also Kameras, Anwesenheit und Schlösser, und kann alles
schalten. Ohne Administratorrechte wiederum gibt Home Assistant die
Bereichsliste nicht heraus, wodurch die App funktionsärmer wirkt, als sie ist.

1. Zweite Instanz starten, z. B.:

   ```bash
   docker run -d --name ha-demo -p 8124:8123 \
     -v /pfad/zu/ha-demo:/config \
     ghcr.io/home-assistant/home-assistant:stable
   ```

2. In `/pfad/zu/ha-demo/configuration.yaml` ergänzen:

   ```yaml
   demo:
   ```

   Das liefert Lichter, Klima, Abdeckungen, Sensoren und einen Media Player.
3. Neu starten, Einrichtungsassistenten durchlaufen, **Administrator-Konto** für
   die Prüfung anlegen
4. **Einstellungen → Bereiche** — drei bis vier Bereiche anlegen und die
   Demo-Geräte zuordnen. Ohne Bereiche bleibt die Räume-Ansicht leer.
5. Ein **Dashboard** mit ein paar Karten anlegen, damit die Dashboard-Auswahl im
   Onboarding nicht leer ist
6. Optional das **Energie-Dashboard** konfigurieren, sonst bleibt dieser Teil
   der App unsichtbar
7. **Von außen erreichbar machen** — die App-Prüfung sitzt nicht in Deutschland,
   eine Adresse im Heimnetz nützt nichts. Entweder Nabu Casa (31 Tage kostenlos)
   oder ein Cloudflare Tunnel auf eine Subdomain.
8. Von einem fremden Netz aus testen, dass Adresse und Anmeldung funktionieren —
   am einfachsten über das Mobilfunknetz des Telefons

## 5 · Screenshots

Mindestens einer in **1920 × 1080**. Im Simulator ⌘S, auf dem Gerät über
Xcode → *Window → Devices and Simulators → Take Screenshot*.

Vorschlag für fünf:

1. Ein Dashboard mit Karten
2. Die Räume-Ansicht
3. Das Energie-Dashboard mit dem Sankey-Diagramm
4. Der Bildschirmschoner mit Hintergrundbild
5. Die Detailansicht einer Lampe oder Klimaanlage

Kein Screenshot sollte das Home-Assistant-Logo als Hauptmotiv zeigen. Taucht es
als Teil eines Dashboards auf, ist das unkritisch.

## 6 · Bauen und hochladen

1. Sicherstellen, dass alles aktuell ist:

   ```bash
   git pull
   python3 Tools/generate_xcodeproj.py
   ```

2. In Xcode das Ziel auf **Any tvOS Device (arm64)** stellen — nicht auf den
   Simulator, sonst ist *Archive* ausgegraut
3. **Product → Archive**
4. Im Organizer **Distribute App → App Store Connect → Upload**
5. Warten, bis die Verarbeitung durch ist (Minuten bis eine Stunde). Danach
   erscheint der Build in App Store Connect unter *TestFlight*

Version und Build stehen in `Resources/Info.plist` auf `1.0` / `1`. **Jeder
weitere Upload braucht eine höhere Build-Nummer** — bei einem abgelehnten oder
korrigierten Build also `CFBundleVersion` hochzählen.

## 7 · TestFlight

1. **TestFlight → Interne Tests**, Gruppe anlegen, sich selbst hinzufügen
2. Auf dem Apple TV die TestFlight-App installieren und HomeDash daraus laden
3. Einmal den kompletten Ablauf durchgehen: Anmeldung, Onboarding, Dashboards,
   Steuerung, Bildschirmschoner

Interne Tests brauchen keine Beta-Prüfung und stehen sofort bereit. Dieser
Schritt ist optional, fängt aber genau die Fehler ab, die sonst eine Ablehnung
und damit eine weitere Wartewoche kosten.

## 8 · Store-Eintrag ausfüllen

Alle Texte stehen fertig in `app-store-listing.md`.

1. **Name, Untertitel, Werbetext, Beschreibung, Keywords** übernehmen.
   Den Markenhinweis am Ende der Beschreibung **nicht kürzen**
2. **Screenshots** hochladen
3. **Support-URL**: `https://github.com/jan620/HA-Apple-TV`
4. **Datenschutz-URL**: `https://jan620.github.io/HA-Apple-TV/`
5. **Kategorie**: Dienstprogramme, sekundär Lifestyle
6. **Altersfreigabe**: alle Fragen mit Nein beantworten, ergibt 4+
7. **Copyright**: `2026 Jan Ananthapavan`

## 9 · Datenschutz und Händlerstatus

1. **App-Datenschutz → Bearbeiten**: auf die Frage *Erfasst diese App Daten?*
   mit **Nein** antworten. Begründung und die entfallenden Folgefragen stehen in
   `app-store-privacy.md`
2. **Tracking über Apps und Websites hinweg**: Nein
3. **Händlerstatus (DSA)** unter *Business → Compliance*: Die Erklärung ist für
   den EU-Vertrieb Pflicht, beide Antworten sind zulässig. Ohne In-App-Käufe ist
   **kein Händler** vertretbar — dann veröffentlicht Apple deine Anschrift
   nicht, blendet aber den Hinweis ein, dass verbraucherschutzrechtliche
   Ansprüche gegenüber dir nicht gelten
4. **Exportbestimmungen**: Die Frage entfällt, weil
   `ITSAppUsesNonExemptEncryption = false` bereits im Info.plist steht

## 10 · Einreichen

1. Build auswählen
2. **App Review Notes** ausfüllen — der fertige Text steht in
   `app-store-listing.md`, es sind nur Adresse, Benutzername und Passwort der
   Demo-Instanz einzusetzen. **Ohne diesen Text wird die App abgelehnt**, weil
   die Prüfung ohne erreichbare Instanz nur den Einrichtungsbildschirm sieht
3. Kontaktdaten für Rückfragen eintragen
4. **Freigabe**: „Manuell freigeben" wählen, dann entscheidest du nach der
   Genehmigung selbst über den Zeitpunkt
5. **Zur Prüfung einreichen**

Die Prüfung dauert erfahrungsgemäß ein bis drei Tage. Bei einer Ablehnung
antwortet man im *Resolution Center* — oft genügt eine Erklärung, ohne dass ein
neuer Build nötig wäre.

## 11 · Nach der Freigabe

1. Demo-Instanz kann vom Netz — aber **vor jedem Update wieder hoch**, denn jede
   Version wird erneut geprüft
2. Release-Tag setzen, damit sich Store-Version und Quellstand zuordnen lassen:

   ```bash
   git tag -a v1.0 -m "Erste Veröffentlichung im App Store"
   git push origin v1.0
   ```

3. Im README auf den App Store verlinken

---

## Was bereits erledigt ist

- Eigenständiges App-Icon in allen geforderten Ebenen samt Top-Shelf-Bildern
- `PrivacyInfo.xcprivacy` mit `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`)
- `ITSAppUsesNonExemptEncryption = false`
- Datenschutzerklärung samt Anbieterangaben nach § 5 DDG, plus Workflow zur
  Veröffentlichung über GitHub Pages
- MIT-Lizenz, Berechtigungstext fürs lokale Netzwerk
- Store-Texte deutsch und englisch samt Markenhinweis, App Review Notes
- Keine In-App-Käufe, keine Analyse- oder Werbe-Bibliotheken, keine
  Fremdabhängigkeiten
- Zwei Sicherheits-Reviews, Befunde behoben
