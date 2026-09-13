#!/usr/bin/env python3
"""Derive light/dark launch assets from the authored icon and semantic ink colors."""

import json
from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "ios/SharedResources/Assets.xcassets"
DESTINATION = CATALOG / "KvilLaunchLogo.imageset"
SVG = "http://www.w3.org/2000/svg"


def main():
    ET.register_namespace("", SVG)
    ink = json.loads((CATALOG / "Ink.colorset/Contents.json").read_text())["colors"]
    DESTINATION.mkdir(parents=True, exist_ok=True)
    images = []
    for appearance in ("light", "dark"):
        tree = ET.parse(ROOT / "design/artwork/icon.svg")
        root = tree.getroot()
        background = root.find(f"{{{SVG}}}g[@id='background']")
        if background is None:
            raise ValueError("The authored icon must contain a background layer.")
        root.remove(background)
        root.set("width", "160")
        root.set("height", "160")
        # Center the visible mark, retaining a quiet margin around it.
        root.set("viewBox", "112 74 800 800")
        color = next(
            item["color"]["components"] for item in ink
            if any(a["value"] == "dark" for a in item.get("appearances", []))
            == (appearance == "dark")
        )
        value = "#" + "".join(
            f"{round(float(color[channel]) * 255):02X}" for channel in ("red", "green", "blue")
        )
        for name, attribute in (("open-circle", "stroke"), ("sun", "fill")):
            group = root.find(f".//{{{SVG}}}g[@id='{name}']")
            if group is None:
                raise ValueError(f"The authored icon must contain {name}.")
            group.set(attribute, value)
        filename = f"kvil-launch-{appearance}.svg"
        tree.write(DESTINATION / filename, encoding="utf-8", xml_declaration=True)
        image = {"filename": filename, "idiom": "universal"}
        if appearance == "dark":
            image["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        images.append(image)
    contents = {
        "images": images,
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (DESTINATION / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Updated {DESTINATION.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
