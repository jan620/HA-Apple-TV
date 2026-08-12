# Datenschutzerklärung für HomeDash

**Stand:** 9. August 2026

> **Vor der Veröffentlichung auszufüllen:** Die DSGVO verlangt in Art. 13 die
> Angabe des Verantwortlichen mit Name und Kontaktdaten. Ersetze die
> Platzhalter unten, sonst ist diese Erklärung unvollständig. Sie ersetzt keine
> Rechtsberatung — bei einer Veröffentlichung mit Einnahmen ist eine anwaltliche
> Prüfung das Geld wert.

## Verantwortlicher

```
[Vor- und Nachname]
[Straße und Hausnummer]
[PLZ und Ort]
E-Mail: [E-Mail-Adresse]
```

## Das Wichtigste in einem Absatz

HomeDash ist ein Anzeige- und Steuerprogramm für deine eigene Home-Assistant-
Installation. Die App spricht ausschließlich mit dem Server, den du selbst
einträgst. Es gibt **keinen Server des Anbieters**, keine Analyse- oder
Absturzberichte, keine Werbung und keine Weitergabe an Dritte. Alle Daten
bleiben zwischen deinem Apple TV und deiner Home-Assistant-Instanz.

## Welche Daten die App verarbeitet

**Zugangsdaten.** Benutzername, Passwort und gegebenenfalls ein
Zwei-Faktor-Code werden bei der Anmeldung eingegeben und direkt an deine
Home-Assistant-Instanz gesendet. Die App speichert sie nicht. Zurück kommt ein
Zugangs- und ein Erneuerungs-Token.

**Tokens.** Diese Tokens liegen in der Schlüsselbund-Verwaltung (Keychain)
deines Apple TV, geschützt durch das Betriebssystem und ausdrücklich
gerätegebunden abgelegt, sodass sie nicht in Gerätesicherungen wandern. Beim
Abmelden werden sie am Server widerrufen und lokal gelöscht.

**Serveradresse und Einstellungen.** Die Adresse deiner Instanz sowie deine
Auswahl aus der Einrichtung (Dashboards, Räume, Bildschirmschoner) liegen in
den App-Einstellungen auf dem Gerät.

**Daten aus deiner Home-Assistant-Instanz.** Um Dashboards anzuzeigen, ruft die
App Zustände und Eigenschaften deiner Entitäten ab. Je nachdem, was du dort
eingerichtet hast, können darunter personenbezogene Daten sein — etwa
Anwesenheit und Standort von Haushaltsmitgliedern, Kamerabilder oder
Verbrauchsverläufe. Diese Daten werden nur zur Anzeige im Arbeitsspeicher
gehalten und nicht dauerhaft auf dem Apple TV gespeichert. Sie verlassen die
Verbindung zwischen App und deiner Instanz nicht.

Standortangaben von `person`- und `device_tracker`-Entitäten (Koordinaten,
Genauigkeit, Akkustand) blendet die App in der Detailansicht bewusst aus: Ein
Fernseher ist ein gemeinsam genutzter Bildschirm.

## Netzwerkverbindungen

Die App verbindet sich ausschließlich mit der von dir eingetragenen
Home-Assistant-Instanz. Zusätzlich sucht sie im lokalen Netzwerk nach Instanzen,
die sich per Bonjour ankündigen; dabei werden nur die vom Server selbst
veröffentlichten Angaben gelesen. tvOS fragt vor der ersten Suche nach deiner
Erlaubnis für den Zugriff auf das lokale Netzwerk.

Verbindungen laufen über HTTPS, sofern deine Instanz das anbietet. Bei
Adressen im Heimnetz ist auch unverschlüsseltes HTTP möglich — in diesem Fall
sind die übertragenen Daten im selben Netzsegment mitlesbar. Die optionale
Einstellung, einem selbstsignierten Zertifikat zu vertrauen, gilt ausschließlich
für den von dir eingetragenen Rechnernamen.

## In-App-Käufe

Die App bietet freiwillige Trinkgelder an. Die Zahlung wickelt Apple ab; die
App erhält lediglich die Information, ob ein Kauf erfolgreich war. Zahlungs-
und Kontodaten sind zu keinem Zeitpunkt für den Anbieter einsehbar. Es gilt
insoweit die [Datenschutzrichtlinie von Apple](https://www.apple.com/legal/privacy/).

## Rechtsgrundlage

Die Verarbeitung erfolgt zur Erfüllung des Nutzungsverhältnisses und damit auf
Grundlage von Art. 6 Abs. 1 lit. b DSGVO. Da keine Daten an den Anbieter
übermittelt werden, findet beim Anbieter keine Verarbeitung statt.

Nutzt du die App rein privat im eigenen Haushalt, greift für dich als Betreiber
deiner Home-Assistant-Instanz in der Regel die Haushaltsausnahme nach Art. 2
Abs. 2 lit. c DSGVO. Sobald du Daten anderer Personen verarbeitest — etwa
Anwesenheit von Mitbewohnern oder Kameraaufnahmen, die über dein Grundstück
hinausreichen — kann das anders zu bewerten sein. Das betrifft deine
Home-Assistant-Konfiguration, nicht diese App.

## Speicherdauer und Löschung

Tokens und Einstellungen bleiben gespeichert, bis du dich abmeldest oder die App
löschst. **Abmelden** widerruft den Zugang am Server und entfernt alle lokalen
Zugangsdaten. **Löschen der App** entfernt alle von ihr gespeicherten Daten vom
Gerät. Daten in deiner Home-Assistant-Instanz bleiben davon unberührt und sind
dort zu verwalten.

## Deine Rechte

Dir stehen die Rechte aus Art. 15 bis 21 DSGVO zu — Auskunft, Berichtigung,
Löschung, Einschränkung, Datenübertragbarkeit und Widerspruch. Da beim Anbieter
keine personenbezogenen Daten vorliegen, laufen Auskunfts- und Löschansprüche
gegenüber dem Anbieter ins Leere; die Kontrolle über deine Daten liegt
vollständig bei dir und deiner eigenen Installation. Für Beschwerden ist die
Datenschutz-Aufsichtsbehörde deines Bundeslandes zuständig.

## Weitergabe an Dritte, Drittlandtransfer

Es findet keine Weitergabe statt. Die App bindet keine Analyse-, Werbe- oder
Absturzberichts-Bibliotheken ein und überträgt keine Daten außerhalb der
Verbindung zu deiner eigenen Instanz. Ein Drittlandtransfer durch die App
findet nicht statt.

## Änderungen

Diese Erklärung wird angepasst, wenn sich die App ändert. Die jeweils gültige
Fassung liegt im Repository unter `PRIVACY.md`.
