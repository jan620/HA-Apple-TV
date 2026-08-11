#!/usr/bin/env python3
"""Generate the tvOS app icon and top shelf assets.

tvOS icons are *layered*: three separate images that the system slides against
each other for the parallax effect when the icon is focused. That structure is
tedious to assemble by hand, so it is generated — including every Contents.json
the asset catalog needs.

    python3 Tools/generate_app_icon.py

The artwork is deliberately original. Home Assistant's logo is a trademark of
the Open Home Foundation; shipping it as a third-party app icon breaks Apple's
review guideline 5.2.5 and the Foundation's brand policy. A house glyph in a
similar blue carries the same meaning without borrowing the mark — colours are
not trademarked, that specific logo is.

Only the standard library is used: PNGs are written directly, and shapes are
rasterised row by row with analytic edge coverage for smooth outlines.
"""

from __future__ import annotations

import json
import math
import os
import shutil
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND_ASSETS = os.path.join(
    ROOT, "Resources", "Assets.xcassets", "App Icon & Top Shelf Image.brandassets"
)

# Home Assistant blue. A colour is not a trademark.
ACCENT = (3, 169, 244)
DEEP = (10, 24, 44)
NIGHT = (3, 7, 14)
SCREEN = (226, 242, 252)

INFO = {"author": "xcode", "version": 1}


# --------------------------------------------------------------------------
# PNG output
# --------------------------------------------------------------------------

class Canvas:
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.pixels = bytearray(width * height * 4)

    def fill_row(self, y: int, rgb: tuple[int, int, int], alpha: int = 255) -> None:
        start = y * self.width * 4
        self.pixels[start:start + self.width * 4] = bytes((*rgb, alpha)) * self.width

    def blend(self, x: int, y: int, rgb: tuple[int, int, int], coverage: float) -> None:
        if coverage <= 0 or x < 0 or x >= self.width or y < 0 or y >= self.height:
            return
        coverage = min(coverage, 1.0)
        index = (y * self.width + x) * 4
        existing_alpha = self.pixels[index + 3] / 255
        # Source-over compositing, premultiplied on the fly.
        out_alpha = coverage + existing_alpha * (1 - coverage)
        if out_alpha <= 0:
            return
        for channel in range(3):
            source = rgb[channel]
            destination = self.pixels[index + channel]
            value = (source * coverage + destination * existing_alpha * (1 - coverage)) / out_alpha
            self.pixels[index + channel] = int(round(value))
        self.pixels[index + 3] = int(round(out_alpha * 255))

    def span(self, y: int, left: float, right: float, rgb: tuple[int, int, int]) -> None:
        """Horizontal run with fractional coverage at both ends."""
        if y < 0 or y >= self.height or right <= left:
            return

        first = int(math.floor(left))
        last = int(math.ceil(right)) - 1

        if first == last:
            self.blend(first, y, rgb, right - left)
            return

        self.blend(first, y, rgb, first + 1 - left)
        if last > first + 1:
            start = (y * self.width + first + 1) * 4
            count = last - first - 1
            self.pixels[start:start + count * 4] = bytes((*rgb, 255)) * count
        self.blend(last, y, rgb, right - last)

    def write(self, path: str) -> None:
        stride = self.width * 4
        raw = bytearray()
        for y in range(self.height):
            raw.append(0)  # filter type: none
            raw += self.pixels[y * stride:(y + 1) * stride]

        def chunk(tag: bytes, data: bytes) -> bytes:
            return (
                struct.pack(">I", len(data))
                + tag
                + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
            )

        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(b"\x89PNG\r\n\x1a\n")
            handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)))
            handle.write(chunk(b"IDAT", zlib.compress(bytes(raw), 6)))
            handle.write(chunk(b"IEND", b""))


# --------------------------------------------------------------------------
# Artwork
# --------------------------------------------------------------------------

def draw_background(canvas: Canvas) -> None:
    """Vertical gradient with a soft glow behind where the house will sit."""
    center_x = canvas.width / 2
    center_y = canvas.height * 0.52
    radius = max(canvas.width, canvas.height) * 0.42

    for y in range(canvas.height):
        t = y / max(canvas.height - 1, 1)
        base = tuple(int(round(DEEP[i] + (NIGHT[i] - DEEP[i]) * t)) for i in range(3))
        canvas.fill_row(y, base)

        # The glow is wide and faint, so per-row sampling of the vertical
        # distance is enough — no need to touch every pixel individually.
        dy = abs(y - center_y)
        if dy > radius:
            continue
        half = math.sqrt(radius * radius - dy * dy)
        strength = (1 - dy / radius) * 0.16
        for x in range(int(center_x - half), int(center_x + half) + 1):
            if 0 <= x < canvas.width:
                dx = abs(x - center_x) / half if half else 1
                canvas.blend(x, y, ACCENT, strength * (1 - dx))


def house_geometry(canvas: Canvas) -> dict:
    size = min(canvas.width, canvas.height)
    height = size * 0.62
    center_x = canvas.width / 2
    top = (canvas.height - height) / 2

    roof_height = height * 0.42
    return {
        "center_x": center_x,
        "top": top,
        "roof_height": roof_height,
        "roof_half": size * 0.33,
        "body_top": top + roof_height,
        "body_height": height - roof_height,
        "body_half": size * 0.24,
    }


def draw_house(canvas: Canvas) -> None:
    geometry = house_geometry(canvas)
    center_x = geometry["center_x"]

    for y in range(int(geometry["top"]), int(geometry["body_top"] + geometry["body_height"]) + 1):
        if y < geometry["body_top"]:
            # Roof: the half width grows linearly from the apex downwards.
            progress = (y - geometry["top"]) / geometry["roof_height"]
            half = geometry["roof_half"] * progress
        else:
            half = geometry["body_half"]
        canvas.span(y, center_x - half, center_x + half, ACCENT)


def draw_screen(canvas: Canvas) -> None:
    """A screen inside the house — a TV app for a smart home."""
    geometry = house_geometry(canvas)
    center_x = geometry["center_x"]

    width = geometry["body_half"] * 1.25
    height = geometry["body_height"] * 0.52
    top = geometry["body_top"] + geometry["body_height"] * 0.26
    radius = min(width, height) * 0.28

    for y in range(int(top), int(top + height) + 1):
        dy = 0.0
        if y < top + radius:
            dy = radius - (y - top)
        elif y > top + height - radius:
            dy = (y - (top + height - radius))

        inset = 0.0
        if dy > 0:
            inset = radius - math.sqrt(max(radius * radius - dy * dy, 0))

        half = width / 2 - inset
        if half > 0:
            canvas.span(y, center_x - half, center_x + half, SCREEN)


# --------------------------------------------------------------------------
# Asset catalog
# --------------------------------------------------------------------------

def write_json(path: str, payload: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")


def layer(stack_path: str, name: str, sizes: list[tuple[int, int, str]], painter) -> None:
    """One parallax layer, rendered at every scale the stack needs."""
    layer_path = os.path.join(stack_path, f"{name}.imagestacklayer")
    write_json(os.path.join(layer_path, "Contents.json"), {"info": INFO})

    content = os.path.join(layer_path, "Content.imageset")
    images = []
    for width, height, scale in sizes:
        filename = f"{name.lower()}{'' if scale == '1x' else '@' + scale}.png"
        canvas = Canvas(width, height)
        painter(canvas)
        canvas.write(os.path.join(content, filename))
        images.append({"filename": filename, "idiom": "tv", "scale": scale})

    write_json(os.path.join(content, "Contents.json"), {"images": images, "info": INFO})


def image_stack(name: str, sizes: list[tuple[int, int, str]]) -> None:
    stack_path = os.path.join(BRAND_ASSETS, f"{name}.imagestack")
    # Front to back: the system offsets them against each other on focus.
    write_json(
        os.path.join(stack_path, "Contents.json"),
        {
            "info": INFO,
            "layers": [
                {"filename": "Front.imagestacklayer"},
                {"filename": "Middle.imagestacklayer"},
                {"filename": "Back.imagestacklayer"},
            ],
        },
    )
    layer(stack_path, "Back", sizes, draw_background)
    layer(stack_path, "Middle", sizes, draw_house)
    layer(stack_path, "Front", sizes, draw_screen)


def top_shelf(name: str, sizes: list[tuple[int, int, str]]) -> None:
    path = os.path.join(BRAND_ASSETS, f"{name}.imageset")
    images = []
    for width, height, scale in sizes:
        filename = f"topshelf{'' if scale == '1x' else '@' + scale}.png"
        canvas = Canvas(width, height)
        # Not layered: everything composited into one image.
        draw_background(canvas)
        draw_house(canvas)
        draw_screen(canvas)
        canvas.write(os.path.join(path, filename))
        images.append({"filename": filename, "idiom": "tv", "scale": scale})

    write_json(os.path.join(path, "Contents.json"), {"images": images, "info": INFO})


def main() -> int:
    if os.path.isdir(BRAND_ASSETS):
        shutil.rmtree(BRAND_ASSETS)

    write_json(
        os.path.join(BRAND_ASSETS, "Contents.json"),
        {
            "assets": [
                {
                    "filename": "App Icon - App Store.imagestack",
                    "idiom": "tv",
                    "role": "primary-app-icon",
                    "size": "1280x768",
                },
                {
                    "filename": "App Icon.imagestack",
                    "idiom": "tv",
                    "role": "primary-app-icon",
                    "size": "400x240",
                },
                {
                    "filename": "Top Shelf Image Wide.imageset",
                    "idiom": "tv",
                    "role": "top-shelf-image-wide",
                    "size": "2320x720",
                },
                {
                    "filename": "Top Shelf Image.imageset",
                    "idiom": "tv",
                    "role": "top-shelf-image",
                    "size": "1920x720",
                },
            ],
            "info": INFO,
        },
    )

    print("App Icon (400×240) …")
    image_stack("App Icon", [(400, 240, "1x"), (800, 480, "2x")])

    print("App Icon – App Store (1280×768) …")
    image_stack("App Icon - App Store", [(1280, 768, "1x")])

    print("Top Shelf Image (1920×720) …")
    top_shelf("Top Shelf Image", [(1920, 720, "1x"), (3840, 1440, "2x")])

    print("Top Shelf Image Wide (2320×720) …")
    top_shelf("Top Shelf Image Wide", [(2320, 720, "1x"), (4640, 1440, "2x")])

    print(f"Fertig: {os.path.relpath(BRAND_ASSETS, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
