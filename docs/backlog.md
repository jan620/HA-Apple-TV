# Backlog

Was nach 1.0 ansteht. Nichts hiervon hält eine Veröffentlichung auf — es sind
Dinge, die beim Bauen und Testen aufgefallen sind und bewusst zurückgestellt
wurden.

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
