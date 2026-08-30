# Texte für den App-Store-Eintrag

Zum Übernehmen in App Store Connect. Die Zeichengrenzen stehen jeweils dabei;
Apple schneidet stillschweigend ab, wenn sie überschritten werden.

---

## Name (30 Zeichen)

```
Roomglance
```

Der Markenname „Home Assistant" darf hier **nicht** stehen. Er gehört der
Open Home Foundation, und Apples Richtlinie 5.2.5 untersagt die Nutzung fremder
Marken in Namen und Symbolen. Das ist einer der wenigen Punkte, bei denen eine
Ablehnung praktisch sicher wäre.

## Untertitel (30 Zeichen)

```
Dein Zuhause auf dem Fernseher
```

## Werbetext (170 Zeichen, jederzeit änderbar ohne neue Version)

```
Dashboards, Räume und Energieverbrauch nativ auf dem Apple TV — mit
Bildschirmschoner, der die Werte zeigt, die dich interessieren.
```

## Keywords (100 Zeichen, kommagetrennt, keine Leerzeichen nach Kommas)

```
smarthome,hausautomation,dashboard,energie,heizung,rollladen,kamera,lampen,steuerung,zuhause
```

„Home Assistant" bewusst nicht als Keyword: Markenbegriffe im Keyword-Feld sind
ein eigener Ablehnungsgrund, und der Begriff steht ohnehin in der Beschreibung,
wo die Suche ihn ebenfalls findet.

## Beschreibung (4000 Zeichen)

```
Roomglance bringt deine Home-Assistant-Installation auf den Fernseher — nativ
gebaut für tvOS, bedienbar mit der Siri Remote, ohne Umweg über eine Webansicht.

DEINE DASHBOARDS
Die Lovelace-Dashboards, die du dir eingerichtet hast, erscheinen so, wie du sie
angelegt hast. Roomglance liest die Konfiguration von deinem Server und zeichnet
die Karten nativ nach — Kacheln, Entitätenlisten, Thermostate, Wettervorhersage,
Verlaufsdiagramme, Kamerabilder.

RÄUME STATT SUCHEN
Wahlweise baut die App aus deinen Bereichen eigene Ansichten. Ein Tab je Raum,
darin alles, was dort steht. Beim ersten Start entscheidest du, ob du deine
Dashboards, die Räume oder beides sehen willst.

ENERGIE IM BLICK
Das Energie-Dashboard ist vollständig nachgebaut: Netzbezug, Einspeisung,
Eigenverbrauch, Kosten und die Verteilung auf einzelne Geräte, mit
Zeiträumen von heute bis zum laufenden Monat.

STEUERN, NICHT NUR SCHAUEN
Lampen dimmen und einfärben, Heizung regeln, Rollläden fahren, Szenen auslösen,
Wiedergabe steuern. Alles über die Fernbedienung erreichbar, mit
Bedienelementen, die für ein Wohnzimmer gemacht sind und nicht für einen
Mauszeiger.

BILDSCHIRMSCHONER
Wird die App eine Weile nicht bedient, zeigt sie Uhrzeit, Datum und die
Entitäten, die du ausgewählt hast. Auf Wunsch mit Fotos im Hintergrund — aus
dem Medienbereich deiner Instanz oder aus einer Diaschau-Integration. Farbe,
Schriftart und Verzögerung sind einstellbar.

DEINE DATEN BLEIBEN DEINE
Die App spricht ausschließlich mit dem Server, den du einträgst. Es gibt keinen
Server des Anbieters, keine Analyse, keine Werbung, kein Konto. Die Anmeldung
läuft über den Anmeldeweg deiner eigenen Instanz, Zugangsdaten werden nicht
gespeichert, und die Zugangstokens liegen gerätegebunden in der Schlüsselbund-
Verwaltung des Apple TV.

VORAUSSETZUNGEN
Eine eigene Home-Assistant-Installation, erreichbar vom Apple TV aus. Roomglance
ist ein Client — ohne eigene Instanz hat die App nichts anzuzeigen.

QUELLOFFEN
Der vollständige Quelltext liegt öffentlich auf GitHub. Fehler melden,
mitentwickeln oder einfach nachlesen, was die App tut: alles möglich.

---
Roomglance ist ein unabhängiges Projekt und steht in keiner Verbindung zur Open
Home Foundation. „Home Assistant" ist eine Marke der Open Home Foundation und
wird hier ausschließlich genannt, um den Zweck der App zu beschreiben.
```

**Den letzten Absatz nicht kürzen.** Er ist der Unterschied zwischen einer
zulässigen Zweckangabe und einer Markennutzung, die nach Richtlinie 5.2.5
abgelehnt wird. Er gehört auch in die englische Fassung.

---

## English

**Subtitle (30)**

```
Your home on the big screen
```

**Promotional text (170)**

```
Dashboards, rooms and energy usage, native on Apple TV — with an ambient screen
showing the readings you care about.
```

**Keywords (100)**

```
smarthome,automation,dashboard,energy,heating,blinds,camera,lights,control,house
```

**Description (4000)**

```
Roomglance puts your Home Assistant installation on the television — built
natively for tvOS, operated with the Siri Remote, with no web view in between.

YOUR DASHBOARDS
The Lovelace dashboards you set up appear the way you built them. Roomglance reads
the configuration from your server and draws the cards natively — tiles, entity
lists, thermostats, weather forecasts, history graphs, camera feeds.

ROOMS INSTEAD OF SEARCHING
Alternatively the app builds views from your areas: one tab per room, holding
everything in it. On first launch you decide whether to see your dashboards,
your rooms, or both.

ENERGY AT A GLANCE
The energy dashboard is rebuilt in full: grid consumption, what you feed back,
self-consumption, cost, and the split across individual devices, over periods
from today to the current month.

CONTROL, NOT JUST DISPLAY
Dim and colour lights, set the heating, move blinds, trigger scenes, control
playback. All reachable from the remote, with controls made for a living room
rather than a mouse pointer.

AMBIENT SCREEN
When the app sits idle it shows the time, the date and the entities you picked.
Optionally with photographs behind them, from your instance's media library or
from a slideshow integration. Colour, typeface and delay are yours to set.

YOUR DATA STAYS YOURS
The app talks to nothing but the server you enter. There is no vendor server, no
analytics, no advertising, no account. Sign-in goes through your own instance,
credentials are never stored, and access tokens live in the Apple TV keychain,
bound to the device.

REQUIREMENTS
Your own Home Assistant installation, reachable from the Apple TV. Roomglance is a
client — without an instance of your own there is nothing for it to show.

OPEN SOURCE
The complete source is public on GitHub. Report a bug, contribute, or simply
read what the app does.

---
Roomglance is an independent project and is not affiliated with the Open Home
Foundation. "Home Assistant" is a trademark of the Open Home Foundation, used
here solely to describe what the app is for.
```

---

## App Review Notes

Der Text, der bei der Einreichung ins Feld *Notes* gehört. Die Platzhalter vor
dem Absenden ersetzen.

```
This app is a client for Home Assistant, a self-hosted home automation server.
It has no backend of its own — it only talks to the server the user enters, so
it cannot be evaluated without one.

We have set up a demo instance for review:

  Server address: https://[ADRESSE-DER-DEMO-INSTANZ]
  Username:       [BENUTZERNAME]
  Password:       [PASSWORT]

How to use it:
1. Launch the app. On the setup screen, enter the server address above.
   The address can be typed with the remote; Bonjour discovery only finds
   instances on the same local network and will find nothing here.
2. Sign in with the credentials above.
3. A short setup asks what to display. Choose "Beides" / "Both" and confirm
   each step to see the full app.
4. The tab bar then holds the dashboards and one tab per room. The first tab
   also contains the settings, including the ambient screen.

The instance is populated with demo devices — lights, climate, covers, sensors,
a media player — plus an energy dashboard, so every card type has something to
display. Controls are live: switching a light in the app changes it on the demo
instance.

The account is an administrator account on a throwaway instance. It contains no
personal data.

Please contact us if the instance is unreachable at the time of review; it is
kept online specifically for this submission.
```

**Auf Englisch lassen.** Die App-Prüfung findet nicht in Deutschland statt.

---

## Was nicht in den Eintrag gehört

- **Das Home-Assistant-Logo**, in keinem Screenshot als Hauptmotiv und nicht als
  Icon. Wenn es in einem Screenshot als Teil eines Dashboards auftaucht, ist das
  unkritisch; als Werbemittel wäre es Markennutzung.
- **Preisangaben oder Spendenaufrufe.** Hinweise auf externe Zahlungswege sind
  nach Richtlinie 3.1.1 unzulässig, auch in der Beschreibung.
- **Versprechen für die Zukunft.** „Demnächst mit …" führt regelmäßig zu
  Rückfragen; beschrieben wird, was die eingereichte Version kann.
