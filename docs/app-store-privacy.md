# Privacy Nutrition Labels — Antworten für App Store Connect

Ausfüllhilfe für *App Store Connect → App-Datenschutz*. Die Begründungen stehen
dabei, damit die Angaben bei einer Rückfrage belegbar sind.

## Die Kernfrage

> Erfasst diese App Daten?

**Nein — „Data Not Collected".**

Apple definiert „erfassen" als das Übertragen von Daten vom Gerät weg, sodass
sie für dich oder deine Partner länger zugänglich sind als für die
Beantwortung der Anfrage in Echtzeit nötig. HomeDash überträgt Daten
ausschließlich an die Home-Assistant-Instanz, die der Nutzer selbst einträgt und
betreibt. Es gibt keinen Server des Anbieters, keine Analyse-Bibliothek, keinen
Absturzbericht-Dienst und keine Werbe-SDKs.

Dass die App personenbezogene Daten *anzeigt* — Anwesenheit, Kamerabilder,
Verbrauchswerte — ist für diese Frage unerheblich: Empfänger ist immer nur der
Server des Nutzers.

## Folgefragen, die dann entfallen

Bei „Data Not Collected" fragt App Store Connect weder nach Datenkategorien noch
nach Verknüpfung mit der Identität oder Tracking. Zwei Angaben bleiben:

| Feld | Antwort |
|---|---|
| Tracking über Apps und Websites hinweg | **Nein** |
| Datenschutzerklärung (URL) | Pflichtfeld — siehe unten |

## Der eine Punkt, den du prüfen solltest

**In-App-Käufe.** Die App bietet Trinkgelder an. Die Zahlung wickelt Apple ab;
die App bekommt nur zurück, ob der Kauf erfolgreich war, und speichert nichts
davon. Daten, die Apple im Rahmen des App-Store-Kaufvorgangs selbst verarbeitet,
musst du nicht als eigene Erfassung angeben.

Trotzdem der Hinweis: Das ist die einzige Stelle, an der die Einordnung
„Data Not Collected" begründungsbedürftig ist. Falls du später eine
Serverkomponente ergänzt, die Käufe validiert oder Spender vermerkt, ändert sich
die Antwort — dann wären mindestens „Purchases" und „Identifiers" anzugeben.

## Privacy Manifest

`Resources/PrivacyInfo.xcprivacy` liegt im Bundle und deklariert:

- **Kein Tracking**, keine Tracking-Domains, keine erfassten Datenkategorien.
- **`NSPrivacyAccessedAPICategoryUserDefaults` mit Grund `CA92.1`.** UserDefaults
  steht auf Apples Liste der APIs, deren Nutzung begründet werden muss. Die App
  legt dort ausschließlich eigene Einstellungen ab — Serveradresse, Auswahl aus
  der Einrichtung, Bildschirmschoner-Konfiguration. Genau das deckt `CA92.1` ab.

Weitere begründungspflichtige APIs (Dateizeitstempel, Systemlaufzeit,
freier Speicherplatz, aktive Tastatur) nutzt die App nicht.

## Datenschutzerklärung hosten

App Store Connect verlangt eine öffentlich erreichbare URL. `PRIVACY.md` liegt
im Repository; für eine zitierfähige Adresse bieten sich an:

- **GitHub Pages** aus diesem Repository — stabile Adresse, versioniert.
- Die Rohansicht auf GitHub — funktioniert, wirkt aber unfertig.
- Eine eigene Domain, falls vorhanden.

**Vor dem Einreichen auszufüllen:** Die Anbieterangaben in `PRIVACY.md` sind
Platzhalter. Sie folgen der Anbieterkennzeichnung nach § 5 DDG, nicht Art. 13
DSGVO — Verantwortlicher im Sinne der DSGVO ist der Betreiber der jeweiligen
Home-Assistant-Instanz, nicht du. Apple prüft außerdem, ob unter der angegebenen
URL überhaupt etwas Passendes steht.

**Händlerstatus (DSA).** Für die Verbreitung im EU-Store musst du in App Store
Connect erklären, ob du Händler bist. Die Erklärung selbst ist Pflicht: Apps
*ohne* Angabe sind seit dem 17. Februar 2025 in den EU-Storefronts nicht mehr
verfügbar. Beide Antworten sind aber zulässig:

- **Händler.** Apple veröffentlicht Anschrift, Telefonnummer und E-Mail auf der
  App-Store-Seite in den 27 EU-Ländern. Für Einzelpersonen akzeptiert Apple an
  dieser Stelle ausdrücklich auch ein **Postfach** — das ist ein anderer
  Maßstab als die ladungsfähige Anschrift, die § 5 DDG für die
  Anbieterkennzeichnung verlangt.
- **Kein Händler.** Die App bleibt im EU-Store verfügbar, Apple blendet dann
  aber den Hinweis ein, dass die verbraucherschutzrechtlichen Ansprüche
  gegenüber dir nicht gelten.

Ob du Händler bist, hängt daran, ob du die App zu gewerblichen Zwecken
anbietest — In-App-Käufe sind dafür das deutlichste Indiz. Diese Einordnung
hängt nicht an der Datenschutzerklärung, sondern an der Monetarisierung.

## Berechtigungstexte

Die Verwendungszwecke in `Resources/Info.plist` liest die App-Prüfung mit:

| Schlüssel | Zweck |
|---|---|
| `NSLocalNetworkUsageDescription` | Bonjour-Suche und Verbindungen im Heimnetz |

Der Text sollte konkret bleiben („Zum Finden und Steuern deiner Home Assistant
Instanz im Heimnetzwerk"); generische Formulierungen führen regelmäßig zu
Rückfragen.

## Nicht enthalten, bewusst

Kein Analyse-Framework, kein Absturzbericht-Dienst, keine Werbe-Kennung, kein
Login über Dritte, keine Kontaktdaten-, Foto- oder Mikrofonzugriffe. Sollte
davon etwas dazukommen, sind sowohl diese Antworten als auch das Privacy
Manifest anzupassen.
