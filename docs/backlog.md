# Backlog

Was nach 1.0 ansteht. Nichts hiervon hält eine Veröffentlichung auf — es sind
Dinge, die beim Bauen und Testen aufgefallen sind und bewusst zurückgestellt
wurden.

---

## Bildschirmschoner: Farbe und Schrift in der Auswahl zeigen

Unter **Darstellung** stehen zwei Auswahlreihen, die beide nur ihren eigenen
Namen anzeigen: „Blau", „Bernstein", „Grün" … und „Rund", „Standard", „Serif",
„Technisch". Man muss die Auswahl schließen und den Bildschirmschoner starten,
um zu sehen, was man gewählt hat.

Beides lässt sich in der Auswahl selbst zeigen:

- **Farbe** — einen gefüllten Punkt in der jeweiligen Akzentfarbe vor den
  Namen setzen. Die Farben stehen in `ScreensaverPalette.accent`.
- **Schrift** — den Namen in der Schrift setzen, die er benennt. „Serif" in
  einer Serifenschrift, „Technisch" dicktengleich. Die Zuordnung steht in
  `ScreensaverTypeface.design`.

Dafür muss `RemoteOptionPicker` in `Sources/UI/FocusControls.swift` (Zeile 141)
mehr können als heute: die Beschriftung ist dort auf `(String) -> String`
festgelegt und wird als einfacher `Text` gezeichnet. Entweder bekommt der
Picker eine zweite Fassung mit `@ViewBuilder`-Beschriftung, oder die beiden
Reihen in `ScreensaverSettingsView.swift` (Zeilen 181–199) benutzen eine eigene
Variante. Die übrigen Aufrufe des Pickers sollen unverändert weiterlaufen.

---

## Bildschirmschoner: Uhrzeit sitzt nicht mittig

Die Uhr steht sichtbar links von der Mitte. Am deutlichsten fällt es auf, wenn
im Hintergrund zwei Bilder nebeneinander stehen — deren Kante ist eine feste
senkrechte Linie, und der Doppelpunkt der Uhrzeit liegt nicht darauf.

Der wahrscheinliche Grund steht in `Sources/Screensaver/ScreensaverView.swift`,
Zeilen 36–38 und 72:

```swift
let horizontal = sin(seconds / 47) * 70
let vertical   = cos(seconds / 61) * 45
...
.offset(x: horizontal, y: vertical)
```

Das ist die Einbrennschutz-Wanderung. Sie verschiebt Uhr und Kacheln um bis zu
70 Punkte nach links oder rechts, mit einer Periode von knapp fünf Minuten. Wer
kurz hinschaut, sieht keine Bewegung, sondern eine falsch zentrierte Uhr.

**Erst prüfen, dann ändern**: `horizontal` und `vertical` versuchsweise auf `0`
setzen. Steht die Uhr dann mittig, ist die Ursache bestätigt; steht sie weiter
links, liegt eine echte Asymmetrie im Aufbau vor und die Wanderung ist
unschuldig.

Wenn es die Wanderung ist, gibt es zwei Wege. Entweder den Hintergrund
mitwandern lassen — leicht vergrößert, damit an den Rändern nichts Schwarzes
auftaucht — sodass es im Bild keine feste Bezugslinie mehr gibt. Oder den
Ausschlag deutlich verkleinern und die Periode verlängern, sodass die
Abweichung unter der Wahrnehmungsschwelle bleibt. Der Einbrennschutz darf dabei
nicht wegfallen: die Ansicht läuft stundenlang unbeaufsichtigt auf einem
Fernsehpanel.

---

## Energie-Ansicht: „Strombezug" umbenennen

Im Energie-Dashboard stehen zwei Kacheln nebeneinander, deren Namen sich kaum
unterscheiden, deren Einheiten aber verschieden sind:

| Kachel | Einheit |
|---|---|
| **Netzbezug** | kWh |
| **Strombezug** | € |

Vorschlag: die Geld-Kachel in **„Bezugskosten"** umbenennen. Analog dazu die
Einspeisungs-Kachel prüfen, die es ebenfalls zweimal gibt — einmal in kWh,
einmal in Euro.

Betrifft `Sources/Energy/EnergyView.swift`, Zeilen um 109–118.

---

## Generierte Projektdatei aus der Versionierung nehmen

`Roomglance.xcodeproj/project.pbxproj` wird von `Tools/generate_xcodeproj.py`
erzeugt und ist trotzdem eingecheckt. Sobald in `Tools/development-team.txt`
eine Team-ID steht, weicht die lokal erzeugte Datei zwangsläufig von der
eingecheckten ab — und **jeder `git pull` bricht ab**, der sie mitbringt.

Der Ausweg ist jedes Mal derselbe:

```bash
git checkout -- Roomglance.xcodeproj/project.pbxproj
```

Sauber wäre, das Verzeichnis in die `.gitignore` zu nehmen. Die Pipeline
erzeugt die Datei ohnehin als ersten Schritt, und wer klont, führt den
Generator einmal aus — das steht bereits in README und Abhakliste.

Was dabei entfällt: der CI-Schritt „Projektdatei ist unverändert", der heute
prüft, dass niemand eine von Xcode überschriebene Fassung mitcheckt. Ohne
eingecheckte Datei gibt es nichts mehr zu vergleichen — das Problem
verschwindet damit aber auch.

**Nicht kurz vor einer Einreichung anfassen.** Wenn dabei etwas schiefgeht,
steht der Build.

---

## `_UIReplicantView`-Warnung im Xcode-Protokoll

```
Adding '_UIReplicantView' as a subview of UIHostingController.view is not
supported and may result in a broken view hierarchy.
```

Entsteht in SwiftUIs Fokusmaschinerie auf tvOS, nicht in eigenem Code, und hat
bisher keine sichtbare Auswirkung. Nachgehen, falls Kacheln beim Fokussieren
flackern oder falsch stehenbleiben.
