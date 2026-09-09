#!/usr/bin/env python3
"""Wandelt PRIVACY.md in Fließtext zum Einfügen in App Store Connect.

App Store Connect hat für tvOS ein eigenes Feld „Datenschutzrichtlinie für
Apple TV". Auf einem Fernseher lässt sich keine Adresse aufrufen, deshalb will
Apple dort den **Text** hinterlegt haben und nicht bloß den Link. Das Feld
nimmt keine Auszeichnung an — Rauten, Sternchen und `<br>` würden wörtlich
erscheinen.

Quelle bleibt PRIVACY.md, damit Seite und Store-Feld nicht auseinanderlaufen.
Der interne Hinweisblock wird wie beim HTML-Bau entfernt.

    python3 Tools/privacy_plaintext.py            # auf die Standardausgabe
    python3 Tools/privacy_plaintext.py datei.txt  # in eine Datei
"""

from __future__ import annotations

import os
import re
import sys

# Wiederverwendet die Entfernung des Hinweisblocks, damit es nur eine
# Fassung dieser Logik gibt.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_privacy_page import SOURCE, check_placeholders, strip_editorial_note


def to_plaintext(markdown: str) -> str:
    text = strip_editorial_note(markdown)

    zeilen: list[str] = []
    for zeile in text.split("\n"):
        # `<br>` trennt die Anschrift; im Fließtext ist das ein Zeilenumbruch.
        zeile = zeile.replace("<br>", "")

        # Überschriften: die Raute weg, der Text bleibt als Absatzkopf stehen.
        zeile = re.sub(r"^#{1,6}\s*", "", zeile)

        # Fett und kursiv. Erst die doppelten Sternchen, sonst bleibt je einer
        # stehen.
        zeile = zeile.replace("**", "")
        zeile = re.sub(r"(?<!\w)\*(?!\s)(.+?)(?<!\s)\*(?!\w)", r"\1", zeile)

        # `Code` in Anführungszeichen — sonst wirken die Backticks wie Tippfehler.
        zeile = re.sub(r"`([^`]+)`", r"„\1“", zeile)

        # Links: den Text behalten, die Adresse in Klammern dahinter.
        zeile = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", zeile)

        zeilen.append(zeile.rstrip())

    # Mehr als eine Leerzeile bringt im Formularfeld nichts.
    ergebnis = "\n".join(zeilen)
    ergebnis = re.sub(r"\n{3,}", "\n\n", ergebnis)
    return ergebnis.strip() + "\n"


def main() -> int:
    with open(SOURCE, encoding="utf-8") as handle:
        markdown = handle.read()

    offen = check_placeholders(markdown)
    if offen:
        print(f"Unausgefüllte Platzhalter: {', '.join(offen)}", file=sys.stderr)
        return 1

    text = to_plaintext(markdown)

    if len(sys.argv) > 1:
        with open(sys.argv[1], "w", encoding="utf-8") as handle:
            handle.write(text)
        print(f"Geschrieben: {sys.argv[1]} ({len(text)} Zeichen)", file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
