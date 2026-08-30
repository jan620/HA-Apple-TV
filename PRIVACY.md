# Datenschutzerklärung für Roomglance

**Stand:** 12. August 2026

> **Vor der Veröffentlichung auszufüllen:** die Anbieterangaben unten. Sie
> folgen der Anbieterkennzeichnung nach § 5 DDG, nicht Art. 13 DSGVO — beim
> Anbieter findet keine Verarbeitung personenbezogener Daten statt, siehe unten.
> Die Pflicht trifft geschäftsmäßig angebotene digitale Dienste; Roomglance ist
> kostenlos und ohne Kaufangebote, sodass sich darüber streiten lässt — die
> Angabe ist im Zweifel die sichere Seite. Wird sie gemacht, muss die Anschrift
> ladungsfähig sein; ein Postfach genügt dafür nicht.
>
> Dieses Dokument ersetzt keine Rechtsberatung; bei einer Veröffentlichung mit
> Einnahmen ist eine anwaltliche Prüfung das Geld wert, weil eine fehlerhafte
> Anbieterkennzeichnung abmahnfähig ist. Dieser Hinweisblock erscheint auf der
> veröffentlichten Seite nicht — `Tools/build_privacy_page.py` entfernt ihn.

## Anbieter

Angaben nach § 5 DDG:

Jan Ananthapavan<br>
Sandäckerweg 9<br>
76646 Bruchsal<br>
E-Mail: jan_anan@yahoo.de

## Wer ist Verantwortlicher im Sinne der DSGVO?

**Nicht der Anbieter dieser App.** Roomglance überträgt keine Daten an den
Anbieter; es existiert keine Serverkomponente, die Daten entgegennehmen könnte.
Verantwortlicher für die Daten, die in der App sichtbar werden, ist der Betreiber
der jeweiligen Home-Assistant-Instanz — also in aller Regel du selbst.

Die folgenden Abschnitte beschreiben deshalb, **was die App auf deinem Gerät
tut**, und nicht, was ein Anbieter mit deinen Daten macht. Er macht nichts damit,
weil er sie nie erhält.

## Das Wichtigste in einem Absatz

Roomglance ist ein Anzeige- und Steuerprogramm für deine eigene Home-Assistant-
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

## Keine Käufe, keine Konten

Die App enthält keine In-App-Käufe, keine Abonnements und kein Konto beim
Anbieter. Es gibt nichts zu bezahlen und nichts zu registrieren; entsprechend
fallen keine Zahlungs-, Vertrags- oder Kontodaten an.

## Rechtsgrundlage

Beim Anbieter entfällt die Frage, weil dort keine Verarbeitung stattfindet.

Für dich als Betreiber deiner Home-Assistant-Instanz gilt: Nutzt du sie rein
privat im eigenen Haushalt, greift in der Regel die Haushaltsausnahme nach
Art. 2 Abs. 2 lit. c DSGVO — die DSGVO ist dann auf dich gar nicht anwendbar.
Sobald du Daten anderer Personen verarbeitest — Anwesenheit von Mitbewohnern,
Kameraaufnahmen, die über dein Grundstück hinausreichen — kann das anders zu
bewerten sein. Das hängt an deiner Home-Assistant-Konfiguration, nicht an dieser
App.

## Speicherdauer und Löschung

Tokens und Einstellungen bleiben gespeichert, bis du dich abmeldest oder die App
löschst. **Abmelden** widerruft den Zugang am Server und entfernt alle lokalen
Zugangsdaten. **Löschen der App** entfernt alle von ihr gespeicherten Daten vom
Gerät. Daten in deiner Home-Assistant-Instanz bleiben davon unberührt und sind
dort zu verwalten.

## Betroffenenrechte

Die Rechte aus Art. 15 bis 21 DSGVO — Auskunft, Berichtigung, Löschung,
Einschränkung, Datenübertragbarkeit und Widerspruch — richten sich gegen den
Verantwortlichen. Das ist hier nicht der Anbieter der App, sondern der Betreiber
der Home-Assistant-Instanz. Ein Auskunftsersuchen an den Anbieter ginge ins
Leere, weil dort schlicht nichts vorliegt.

Möchte eine Person wissen, welche Daten über sie in einer Home-Assistant-Instanz
liegen, oder deren Löschung verlangen, ist das an deren Betreiber zu richten und
dort umzusetzen. Für Beschwerden ist die Datenschutz-Aufsichtsbehörde des
jeweiligen Bundeslandes zuständig.

## Weitergabe an Dritte, Drittlandtransfer

Es findet keine Weitergabe statt. Die App bindet keine Analyse-, Werbe- oder
Absturzberichts-Bibliotheken ein und überträgt keine Daten außerhalb der
Verbindung zu deiner eigenen Instanz. Ein Drittlandtransfer durch die App
findet nicht statt.

## Änderungen

Diese Erklärung wird angepasst, wenn sich die App ändert. Die jeweils gültige
Fassung liegt im Repository unter `PRIVACY.md`.
