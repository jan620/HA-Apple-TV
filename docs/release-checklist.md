# Veröffentlichung im App Store — Reihenfolge zum Abhaken

Alles, was zwischen dem heutigen Stand und einer freigegebenen App liegt. Die
Reihenfolge ist nicht willkürlich: Jeder Block setzt den vorigen voraus.

---

## 1. Konto und Name

- [ ] **Apple Developer Program**, 99 €/Jahr. Die Aufnahme kann Tage dauern und
      blockiert alles Weitere — TestFlight ebenso wie den Store.
      Als Einzelperson wird der eigene Name zum Entwicklernamen im Store; eine
      Organisation setzt eine D-U-N-S-Nummer und damit ein Unternehmen voraus.
- [ ] **App-Eintrag in App Store Connect anlegen**, sobald das Konto steht.
      Damit ist der Name „HomeDash" reserviert. Namen werden nicht geteilt, und
      ein besetzter Name ist später nur noch mit Zusatz zu haben.
- [ ] **Bundle-ID registrieren:** `io.github.jan620.homedash`. Muss exakt zu
      `PRODUCT_BUNDLE_IDENTIFIER` im Projekt passen.
- [ ] **Signing-Team lokal hinterlegen** (siehe README, Abschnitt *Bauen und
      installieren*) — nicht in Xcode setzen, sonst kollidiert es beim nächsten
      `git pull` mit der generierten Projektdatei.

## 2. Die Instanz für die App-Prüfung

**Das ist der häufigste Ablehnungsgrund für Apps zu selbstgehosteten Diensten.**
Ohne erreichbare Instanz sieht die Prüfung nur den Einrichtungsbildschirm und
bewertet die App als unvollständig (Richtlinie 2.1).

- [ ] **Eigene Demo-Instanz aufsetzen** — nicht die produktive. Begründung siehe
      unten unter *Warum keine Konten auf der eigenen Instanz*.
- [ ] Die `demo`-Integration aktivieren; sie liefert Lichter, Klima, Abdeckungen,
      Sensoren und einen Media Player, also genug, damit die Kartentypen der App
      etwas zu zeigen haben.
- [ ] **Bereiche anlegen** und Geräte zuordnen — sonst bleibt die Räume-Ansicht
      leer.
- [ ] Ein **Dashboard** mit ein paar Karten anlegen, damit die Dashboard-Auswahl
      im Onboarding nicht leer ist.
- [ ] Optional: **Energie-Dashboard** konfigurieren, sonst bleibt dieser Teil der
      App unsichtbar.
- [ ] **Von außen erreichbar machen**, für die Dauer der Prüfung. Nabu Casa
      (31 Tage kostenlos zum Testen) oder ein Cloudflare Tunnel. Die Prüfung
      sitzt nicht in Deutschland — eine Adresse im Heimnetz nützt nichts.
- [ ] **Administrator-Konto für die Prüfung** anlegen. Ohne Adminrechte gibt
      Home Assistant die Bereichsliste nicht heraus, und die App wirkt dadurch
      funktionsärmer, als sie ist.
- [ ] Adresse, Benutzername und Passwort in die **App Review Notes** eintragen
      (Text steht in `app-store-listing.md`).

### Warum keine Konten auf der eigenen Instanz

Home Assistant kennt keine Berechtigungen je Entität. Ein Benutzer ist
Administrator oder nicht — und auch ein Nicht-Administrator sieht **sämtliche
Entitäten**: Kamerabilder, Anwesenheit der Haushaltsmitglieder, Schlösser,
Verbrauchsverläufe. Ein Konto „mit wenigen Berechtigungen" lässt sich in der
Oberfläche nicht erzeugen.

Dazu kommt: Wer die App bedienen kann, kann auch schalten. Die Prüfung würde
also Lichter, Rollläden und Schlösser in einer bewohnten Wohnung bedienen — und
zwar zu einem Zeitpunkt, den du nicht kennst.

Der Aufwand für eine zweite Instanz ist gering: ein Container mit der
`demo`-Integration reicht.

## 3. Rechtliches und Konten

- [ ] **Datenschutzerklärung öffentlich erreichbar.** `PRIVACY.md` ist fertig
      samt Anbieterangaben; es fehlt nur die URL. Über GitHub Pages heißt sie
      `https://jan620.github.io/HA-Apple-TV/` — dafür muss das Repository
      öffentlich sein und unter *Settings → Pages* als Quelle **GitHub Actions**
      eingestellt werden.
- [ ] **Support-URL.** Das öffentliche Repository genügt; Apple verlangt eine
      Seite, auf der Nutzer Hilfe bekommen.
- [ ] **Händlerstatus nach DSA erklären.** Die Erklärung ist Pflicht für den
      EU-Vertrieb, beide Antworten sind zulässig. Ohne In-App-Käufe ist „kein
      Händler" vertretbar; Apple veröffentlicht dann deine Anschrift **nicht**,
      blendet aber den Hinweis ein, dass Verbraucherrechte gegenüber dir nicht
      gelten. Einzelheiten in `app-store-privacy.md`.
- [ ] **Privacy Nutrition Labels** ausfüllen — „Data Not Collected", Antworten in
      `app-store-privacy.md`.

## 4. Der Eintrag im Store

- [ ] Texte aus `app-store-listing.md` übernehmen: Untertitel, Beschreibung,
      Werbetext, Keywords. **Den Markenhinweis nicht kürzen** (siehe dort).
- [ ] **Screenshots**, mindestens einer in 1920 × 1080. Im Simulator mit
      ⌘S, auf dem Gerät über Xcode → *Window → Devices and Simulators →
      Take Screenshot*. Vorschlag für die Auswahl:
      1. Ein Dashboard mit Karten
      2. Die Räume-Ansicht
      3. Das Energie-Dashboard
      4. Der Bildschirmschoner mit Hintergrundbild
      5. Die Detailansicht einer Lampe oder Klimaanlage
- [ ] **Kategorie:** Dienstprogramme, alternativ Lifestyle.
- [ ] **Altersfreigabe:** 4+. Keine der Fragen trifft zu.
- [ ] **Top-Shelf-Bild** prüfen — liegt im Asset-Katalog, erscheint auf dem
      Home-Bildschirm, wenn die App in der obersten Reihe steht.

## 5. Vor dem Hochladen

- [ ] Auf **echter Hardware** getestet, nicht nur im Simulator. Fokus mit der
      Siri Remote, Kamera-Streams und der Bildschirmschoner verhalten sich dort
      anders.
- [ ] **Version und Build** in `Resources/Info.plist` — `1.0` / `1` für die
      erste Einreichung. Jeder weitere Upload braucht eine höhere Build-Nummer.
- [ ] `xcodebuild test` läuft durch.
- [ ] Archiv bauen (*Product → Archive*) und über den Organizer hochladen.
- [ ] **TestFlight**, mindestens ein Durchgang. Interne Tester brauchen keine
      Beta-Prüfung und sind sofort verfügbar.

## 6. Nach der Freigabe

- [ ] Demo-Instanz wieder vom Netz nehmen — aber **erst nach der Freigabe**, und
      auch bei jedem Update wieder erreichbar machen. Jede neue Version wird
      erneut geprüft.
- [ ] Ko-fi-Handle in `.github/FUNDING.yml` eintragen, falls noch offen.
- [ ] Ein Release-Tag im Repository setzen, damit sich Store-Versionen und
      Quellstand zuordnen lassen.

---

## Was bereits erledigt ist

- Eigenständiges App-Icon in allen geforderten Ebenen samt Top-Shelf-Bildern
- `PrivacyInfo.xcprivacy` mit `NSPrivacyAccessedAPICategoryUserDefaults` (`CA92.1`)
- `ITSAppUsesNonExemptEncryption = false` — beantwortet die Exportfrage einmalig
- Datenschutzerklärung samt Anbieterangaben nach § 5 DDG
- MIT-Lizenz
- Keine In-App-Käufe, keine Analyse- oder Werbe-Bibliotheken, keine
  Fremdabhängigkeiten
- Berechtigungstext für den Zugriff auf das lokale Netzwerk
