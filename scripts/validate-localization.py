#!/usr/bin/env python3
"""Validate catalog translations without generating Swift source."""
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = (
    ROOT / "ios/SharedResources/Localizable.xcstrings",
    ROOT / "ios/KvilApp/Supporting/InfoPlist.xcstrings",
    ROOT / "ios/KvilApp/Supporting/AppShortcuts.xcstrings",
)


def string_units(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "stringUnit":
                yield child
            else:
                yield from string_units(child)


def main():
    for catalog in CATALOGS:
        data = json.loads(catalog.read_text())
        for key, entry in data["strings"].items():
            if entry.get("shouldTranslate") is False:
                continue
            for locale in ("en", "nb"):
                units = list(string_units(entry.get("localizations", {}).get(locale, {})))
                if not units or any(
                    unit.get("state") != "translated"
                    or not isinstance(unit.get("value"), str)
                    or not unit["value"]
                    for unit in units
                ):
                    raise ValueError(f"{catalog.name}: {key} requires a complete {locale} translation")
        with tempfile.TemporaryDirectory(prefix="kvil-localization-") as output:
            subprocess.run(
                ["xcrun", "xcstringstool", "compile", str(catalog),
                 "--output-directory", output, "--dry-run"],
                check=True,
            )
        print(f"Validated {catalog.relative_to(ROOT)} ({len(data['strings'])} entries).")


if __name__ == "__main__":
    main()
