#!/usr/bin/env python3
"""Rendert PRIVACY.md zu einer eigenständigen HTML-Seite für GitHub Pages.

App Store Connect verlangt eine öffentlich erreichbare Adresse für die
Datenschutzerklärung. Veröffentlicht wird deshalb nur dieses eine Dokument —
die Entwicklungsdoku unter docs/ bleibt draußen.

    python3 Tools/build_privacy_page.py [Zielverzeichnis]

Ohne Argument landet das Ergebnis in _site/ (das erwartet die Pages-Action).
"""

import os
import re
import sys

import markdown

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "PRIVACY.md")
DEFAULT_OUTPUT = os.path.join(ROOT, "_site")

TITLE = "Datenschutzerklärung — HomeDash"

# Bewusst ohne externe Schriften oder Skripte: Die Seite soll auch dann
# vollständig sein, wenn ein Prüfer sie mit blockierten Drittanbietern öffnet.
TEMPLATE = """<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="Datenschutzerklärung der tvOS-App HomeDash \
für Home Assistant.">
<meta name="color-scheme" content="light dark">
<style>
:root {{
  --bg: #ffffff;
  --fg: #1c1c1e;
  --muted: #6b6b70;
  --rule: #e2e2e6;
  --accent: #0a84ff;
  --quote-bg: #f4f4f6;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #131315;
    --fg: #ececf0;
    --muted: #9a9aa2;
    --rule: #2c2c31;
    --accent: #4da3ff;
    --quote-bg: #1d1d21;
  }}
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  padding: 3rem 1.5rem 5rem;
  background: var(--bg);
  color: var(--fg);
  font: 17px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
        "Helvetica Neue", Arial, sans-serif;
  -webkit-text-size-adjust: 100%;
}}
main {{ max-width: 44rem; margin: 0 auto; }}
h1 {{ font-size: 2rem; line-height: 1.2; margin: 0 0 1.5rem; }}
h2 {{
  font-size: 1.25rem;
  margin: 2.75rem 0 0.75rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--rule);
}}
p, ul, ol {{ margin: 0 0 1.1rem; }}
ul, ol {{ padding-left: 1.4rem; }}
li {{ margin-bottom: 0.4rem; }}
a {{ color: var(--accent); }}
strong {{ font-weight: 600; }}
code {{
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.9em;
  background: var(--quote-bg);
  padding: 0.15em 0.35em;
  border-radius: 4px;
}}
pre {{
  background: var(--quote-bg);
  padding: 1rem 1.1rem;
  border-radius: 8px;
  overflow-x: auto;
}}
pre code {{ background: none; padding: 0; }}
blockquote {{
  margin: 1.5rem 0;
  padding: 1rem 1.2rem;
  background: var(--quote-bg);
  border-left: 3px solid var(--rule);
  border-radius: 0 8px 8px 0;
  color: var(--muted);
}}
blockquote p:last-child {{ margin-bottom: 0; }}
footer {{
  max-width: 44rem;
  margin: 4rem auto 0;
  padding-top: 1.5rem;
  border-top: 1px solid var(--rule);
  color: var(--muted);
  font-size: 0.9rem;
}}
</style>
</head>
<body>
<main>
{body}
</main>
<footer>
<p>HomeDash ist quelloffen. Der Stand dieses Dokuments liegt im
<a href="https://github.com/jan620/HA-Apple-TV/blob/main/PRIVACY.md">Repository</a>.</p>
</footer>
</body>
</html>
"""


def strip_editorial_note(text: str) -> str:
    """Entfernt den internen Hinweis-Block am Anfang.

    Die Anmerkung „vor der Veröffentlichung auszufüllen" richtet sich an den
    Anbieter, nicht an Nutzer der App, und hat auf der veröffentlichten Seite
    nichts verloren.
    """
    lines = text.split("\n")
    kept = []
    in_note = False
    for line in lines:
        if line.startswith(">"):
            if not in_note and "auszufüllen" in line:
                in_note = True
            if in_note:
                continue
        elif in_note and not line.strip():
            in_note = False
            continue
        else:
            in_note = False
        kept.append(line)
    return "\n".join(kept)


def check_placeholders(text: str) -> list:
    """Findet unausgefüllte Platzhalter der Form [Vor- und Nachname]."""
    return re.findall(r"\[([A-ZÄÖÜ][^\]\n]{3,40})\]", text)


def build(output_dir: str) -> str:
    with open(SOURCE, encoding="utf-8") as handle:
        source = handle.read()

    for placeholder in check_placeholders(source):
        print(f"  Hinweis: Platzhalter noch offen — [{placeholder}]")

    body = markdown.markdown(
        strip_editorial_note(source),
        extensions=["extra", "sane_lists"],
        output_format="html5",
    )

    os.makedirs(output_dir, exist_ok=True)
    target = os.path.join(output_dir, "index.html")
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(TEMPLATE.format(title=TITLE, body=body))

    # Ohne diese Datei schickt GitHub Pages den Inhalt durch Jekyll, das
    # Verzeichnisse mit führendem Unterstrich verwirft.
    with open(os.path.join(output_dir, ".nojekyll"), "w") as handle:
        handle.write("")

    return target


if __name__ == "__main__":
    destination = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUTPUT
    written = build(destination)
    print(f"Geschrieben: {os.path.relpath(written, ROOT)}")
