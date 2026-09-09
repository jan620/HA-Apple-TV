#!/usr/bin/env python3
"""Richtet die Demo-Instanz für die App-Prüfung ein, ohne Klickarbeit.

Legt Bereiche an, verteilt die Demo-Entitäten darauf, baut ein Dashboard mit
den Kartentypen, die Roomglance nativ zeichnet, und konfiguriert das
Energie-Dashboard.

Gearbeitet wird über dieselbe WebSocket-Schnittstelle, die auch die Oberfläche
benutzt. Entitäten werden **nicht geraten**, sondern aus der laufenden Instanz
gelesen — das Skript funktioniert deshalb auch, wenn die Demo-Integration in
einer neueren Home-Assistant-Fassung andere Entitäten liefert.

Das Skript ist wiederholbar: vorhandene Bereiche werden erkannt und nicht
doppelt angelegt.

Aufruf am einfachsten im Container, dort ist `aiohttp` bereits vorhanden:

    docker compose cp seed_demo.py homeassistant:/tmp/seed_demo.py
    docker compose exec homeassistant \\
        python /tmp/seed_demo.py --token <LANGZEIT-TOKEN>

Den Token gibt es in der Oberfläche unter *Profil → Sicherheit →
Langlebige Zugangstoken → Token erstellen*.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from typing import Any

import aiohttp


ROOMS = ["Wohnzimmer", "Küche", "Schlafzimmer", "Büro"]

# Diese Domänen landen in den Räumen. Die Reihenfolge bestimmt, was ein Raum
# zuerst bekommt — Licht und Klima sind die dankbarsten Kacheln.
ROOM_DOMAINS = ["light", "climate", "cover", "sensor", "binary_sensor", "media_player"]

DASHBOARD_PATH = "demo-dashboard"
DASHBOARD_TITLE = "Demo"


class Client:
    """Minimaler Client für die WebSocket-Schnittstelle von Home Assistant."""

    def __init__(self, session: aiohttp.ClientSession, url: str, token: str) -> None:
        self._session = session
        self._url = url.rstrip("/") + "/api/websocket"
        self._token = token
        self._socket: aiohttp.ClientWebSocketResponse | None = None
        self._id = 0

    async def __aenter__(self) -> "Client":
        self._socket = await self._session.ws_connect(self._url, heartbeat=30)
        # Erste Nachricht ist immer `auth_required`.
        await self._socket.receive_json()
        await self._socket.send_json({"type": "auth", "access_token": self._token})
        reply = await self._socket.receive_json()
        if reply.get("type") != "auth_ok":
            raise SystemExit(f"Anmeldung fehlgeschlagen: {reply.get('message', reply)}")
        return self

    async def __aexit__(self, *_: object) -> None:
        if self._socket is not None:
            await self._socket.close()

    async def send(self, **payload: Any) -> Any:
        """Ein Kommando absenden und das Ergebnis zurückgeben."""
        assert self._socket is not None
        self._id += 1
        await self._socket.send_json({"id": self._id, **payload})
        while True:
            message = await self._socket.receive_json()
            if message.get("id") != self._id:
                continue  # Ereignisse anderer Abonnements überspringen.
            if not message.get("success", False):
                error = message.get("error", {})
                raise SystemExit(
                    f"{payload.get('type')} fehlgeschlagen: "
                    f"{error.get('message', message)}"
                )
            return message.get("result")


async def ensure_areas(client: Client) -> dict[str, str]:
    """Bereiche anlegen, soweit sie noch fehlen. Gibt Name → area_id zurück."""
    existing = {area["name"]: area["area_id"] for area in await client.send(
        type="config/area_registry/list"
    )}

    areas: dict[str, str] = {}
    for name in ROOMS:
        if name in existing:
            print(f"  Bereich vorhanden: {name}")
            areas[name] = existing[name]
            continue
        created = await client.send(type="config/area_registry/create", name=name)
        print(f"  Bereich angelegt:  {name}")
        areas[name] = created["area_id"]
    return areas


def group_by_domain(entity_ids: list[str]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = {}
    for entity_id in entity_ids:
        grouped.setdefault(entity_id.split(".", 1)[0], []).append(entity_id)
    for entity_ids_of_domain in grouped.values():
        entity_ids_of_domain.sort()
    return grouped


async def assign_areas(client: Client, areas: dict[str, str]) -> dict[str, list[str]]:
    """Entitäten reihum auf die Bereiche verteilen.

    Je Domäne reihum, damit jeder Raum etwas Sichtbares bekommt statt alle
    Lampen im Wohnzimmer und sonst nichts.
    """
    registry = await client.send(type="config/entity_registry/list")
    # Nur Einträge ohne Bereich anfassen — eine schon getroffene Zuordnung
    # soll ein zweiter Lauf nicht durcheinanderbringen.
    free = [
        entry["entity_id"]
        for entry in registry
        if not entry.get("area_id") and not entry.get("disabled_by")
    ]

    by_domain = group_by_domain(free)
    per_room: dict[str, list[str]] = {name: [] for name in ROOMS}

    for domain in ROOM_DOMAINS:
        for index, entity_id in enumerate(by_domain.get(domain, [])):
            # Sensoren gibt es viele; drei je Raum reichen für eine ruhige Ansicht.
            if domain in ("sensor", "binary_sensor") and index >= len(ROOMS) * 3:
                break
            room = ROOMS[index % len(ROOMS)]
            await client.send(
                type="config/entity_registry/update",
                entity_id=entity_id,
                area_id=areas[room],
            )
            per_room[room].append(entity_id)

    for room, entity_ids in per_room.items():
        print(f"  {room}: {len(entity_ids)} Entitäten")
    return per_room


async def build_dashboard(client: Client, states: dict[str, dict]) -> None:
    """Ein Dashboard mit genau den Karten anlegen, die die App nativ zeichnet."""
    dashboards = await client.send(type="lovelace/dashboards/list")
    if not any(board.get("url_path") == DASHBOARD_PATH for board in dashboards):
        await client.send(
            type="lovelace/dashboards/create",
            url_path=DASHBOARD_PATH,
            title=DASHBOARD_TITLE,
            mode="storage",
            icon="mdi:television-play",
            show_in_sidebar=True,
            require_admin=False,
        )
        print(f"  Dashboard angelegt: {DASHBOARD_TITLE}")
    else:
        print(f"  Dashboard vorhanden: {DASHBOARD_TITLE}")

    by_domain = group_by_domain(list(states))
    cards: list[dict[str, Any]] = []

    entities = by_domain.get("light", [])[:4] + by_domain.get("sensor", [])[:4]
    if entities:
        cards.append({"type": "entities", "title": "Übersicht", "entities": entities})

    if climate := by_domain.get("climate"):
        cards.append({"type": "thermostat", "entity": climate[0]})

    if weather := by_domain.get("weather"):
        cards.append({"type": "weather-forecast", "entity": weather[0]})

    if covers := by_domain.get("cover"):
        cards.append({"type": "entities", "title": "Rollläden", "entities": covers[:4]})

    await client.send(
        type="lovelace/config/save",
        url_path=DASHBOARD_PATH,
        config={"views": [{"title": "Zuhause", "path": "zuhause", "cards": cards}]},
    )
    print(f"  Karten geschrieben: {len(cards)}")


def find_energy_sensor(states: dict[str, dict]) -> str | None:
    """Ein Sensor, den das Energie-Dashboard als Netzbezug akzeptiert.

    Verlangt werden `device_class: energy` und eine aufsummierende
    `state_class` — alles andere weist Home Assistant zurück.
    """
    for entity_id, state in sorted(states.items()):
        attributes = state.get("attributes", {})
        if attributes.get("device_class") != "energy":
            continue
        if attributes.get("state_class") in ("total", "total_increasing"):
            return entity_id
    return None


async def configure_energy(client: Client, states: dict[str, dict]) -> None:
    prefs = await client.send(type="energy/get_prefs")
    if prefs and prefs.get("energy_sources"):
        print("  Energie-Dashboard bereits eingerichtet")
        return

    sensor = find_energy_sensor(states)
    if sensor is None:
        print("  Kein passender Energiesensor gefunden — bitte von Hand eintragen")
        return

    await client.send(
        type="energy/save_prefs",
        energy_sources=[
            {
                "type": "grid",
                "flow_from": [
                    {
                        "stat_energy_from": sensor,
                        "stat_cost": None,
                        "entity_energy_price": None,
                        "number_energy_price": None,
                    }
                ],
                "flow_to": [],
                "cost_adjustment_day": 0.0,
            }
        ],
        device_consumption=[],
    )
    print(f"  Netzbezug: {sensor}")


async def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://localhost:8123")
    parser.add_argument("--token", required=True, help="Langlebiger Zugangstoken")
    args = parser.parse_args()

    async with aiohttp.ClientSession() as session:
        async with Client(session, args.url, args.token) as client:
            states = {
                state["entity_id"]: state
                for state in await client.send(type="get_states")
            }
            print(f"{len(states)} Entitäten gefunden.\n")

            print("Bereiche:")
            areas = await ensure_areas(client)

            print("\nZuordnung:")
            await assign_areas(client, areas)

            print("\nDashboard:")
            await build_dashboard(client, states)

            print("\nEnergie:")
            await configure_energy(client, states)

    print("\nFertig. In der Oberfläche prüfen und bei Bedarf nachjustieren.")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
