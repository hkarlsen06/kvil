#!/usr/bin/env python3
"""Export Kvil's editable SVG using macOS Quick Look. No extra dependencies."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
ARTWORK = ROOT / "design/artwork"
SOURCE = ARTWORK / "icon.svg"
SVG = "http://www.w3.org/2000/svg"


def main():
    # The full icon is the only authored source. Derive a transparent companion
    # with the same geometry and colors for use outside an app icon.
    ET.register_namespace("", SVG)
    tree = ET.parse(SOURCE)
    root = tree.getroot()
    background = root.find(f"{{{SVG}}}g[@id='background']")
    if background is None:
        raise ValueError("The source icon must contain a background layer.")
    root.remove(background)
    root.find(f"{{{SVG}}}desc").text = (
        "An open ivory circle shelters two sage hills and a small sun. "
        "Transparent artwork for use on a dark background."
    )
    tree.write(ARTWORK / "icon-mark.svg", encoding="utf-8", xml_declaration=True)

    with tempfile.TemporaryDirectory(prefix="Kvil-icon-") as directory:
        subprocess.run(
            ["qlmanage", "-t", "-s", "1024", "-o", directory, str(SOURCE)],
            check=True, stdout=subprocess.DEVNULL,
        )
        rendered = Path(directory) / "icon.svg.png"
        if not rendered.is_file():
            raise RuntimeError("Quick Look did not produce the app icon.")
        # Quick Look emits RGBA even for opaque SVGs. Export an sRGB image
        # without an alpha channel for the app catalogs, without JPEG conversion.
        subprocess.run(["swift", "-e", """
import Foundation
import CoreGraphics
import ImageIO

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == 1024, image.height == 1024,
      let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: 1024, height: 1024,
          bitsPerComponent: 8, bytesPerRow: 0, space: space,
          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("Cannot load the 1024-pixel icon.") }
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
guard let opaque = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          output as CFURL, "public.png" as CFString, 1, nil)
else { fatalError("Cannot create the opaque icon.") }
CGImageDestinationAddImage(destination, opaque, nil)
guard CGImageDestinationFinalize(destination)
else { fatalError("Cannot write the opaque icon.") }
""", str(rendered), str(ARTWORK / "icon.png")], check=True)

    for target in ("KvilApp", "KvilWatchApp"):
        destination = ROOT / f"ios/{target}/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
        shutil.copyfile(ARTWORK / "icon.png", destination)
        print(f"Updated {destination.relative_to(ROOT)}")
    print("Updated design/artwork/icon.png and icon-mark.svg")


if __name__ == "__main__":
    main()
