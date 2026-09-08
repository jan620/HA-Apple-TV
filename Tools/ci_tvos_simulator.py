#!/usr/bin/env python3
"""Gibt die UDID eines benutzbaren tvOS-Simulators aus, notfalls neu angelegt.

Hintergrund: `-destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd
generation)'` setzt voraus, dass GitHubs Runner-Abbild genau dieses Gerät
angelegt hat. Das ist nicht zugesichert — die Abbilder wechseln, und ein Abbild
ohne vorangelegtes tvOS-Gerät lässt `xcodebuild test` mit „no available devices
matched the request" scheitern, obwohl die Laufzeit installiert ist.

Deshalb wird hier nachgesehen statt geraten: ein vorhandenes Gerät nehmen, sonst
eines aus der neuesten verfügbaren tvOS-Laufzeit anlegen.

Auf der Standardausgabe steht nur die UDID, damit der Aufrufer sie direkt in
`$GITHUB_OUTPUT` schreiben kann; alles Erklärende geht auf die Fehlerausgabe.
"""

from __future__ import annotations

import json
import subprocess
import sys


DEVICE_NAME = "roomglance-ci"


def simctl(*args: str) -> dict:
    """`xcrun simctl` mit JSON-Ausgabe."""
    raw = subprocess.run(
        ["xcrun", "simctl", *args, "-j"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return json.loads(raw)


def log(message: str) -> None:
    print(message, file=sys.stderr)


def is_tvos(identifier: str, platform: str | None) -> bool:
    """Ältere `simctl`-Fassungen kennen kein `platform`-Feld."""
    if platform:
        return platform == "tvOS"
    return "tvOS" in identifier


def existing_device() -> str | None:
    """UDID eines bereits angelegten, benutzbaren tvOS-Geräts."""
    for runtime, devices in simctl("list", "devices", "available")["devices"].items():
        if "tvOS" not in runtime:
            continue
        for device in devices:
            # `available` filtert bereits, aber nicht jede simctl-Fassung tut
            # das zuverlässig — die Prüfung kostet nichts.
            if device.get("isAvailable", True):
                log(f"Vorhandenes Gerät: {device['name']} ({runtime})")
                return device["udid"]
    return None


def newest_runtime() -> str | None:
    """Bezeichner der neuesten installierten tvOS-Laufzeit."""
    candidates = [
        runtime
        for runtime in simctl("list", "runtimes")["runtimes"]
        if runtime.get("isAvailable")
        and is_tvos(runtime.get("identifier", ""), runtime.get("platform"))
    ]
    if not candidates:
        return None

    def version_key(runtime: dict) -> list[int]:
        parts = str(runtime.get("version", "0")).split(".")
        return [int(part) if part.isdigit() else 0 for part in parts]

    return max(candidates, key=version_key)["identifier"]


def apple_tv_device_type() -> str | None:
    """Bezeichner des neuesten Apple-TV-Gerätetyps."""
    types = [
        device_type
        for device_type in simctl("list", "devicetypes")["devicetypes"]
        if "Apple-TV" in device_type.get("identifier", "")
    ]
    return types[-1]["identifier"] if types else None


def main() -> int:
    udid = existing_device()
    if udid:
        print(udid)
        return 0

    log("Kein tvOS-Gerät vorhanden, lege eines an.")

    runtime = newest_runtime()
    device_type = apple_tv_device_type()

    if not runtime or not device_type:
        log("Keine tvOS-Laufzeit oder kein Apple-TV-Gerätetyp installiert.")
        log("Verfügbare Laufzeiten:")
        for entry in simctl("list", "runtimes")["runtimes"]:
            log(f"  {entry.get('identifier')} (verfügbar: {entry.get('isAvailable')})")
        return 1

    log(f"Laufzeit: {runtime}")
    log(f"Gerätetyp: {device_type}")

    udid = subprocess.run(
        ["xcrun", "simctl", "create", DEVICE_NAME, device_type, runtime],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()

    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
