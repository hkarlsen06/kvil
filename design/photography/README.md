# Kvil landscape photography

Selected on 13 September 2026 after comparing free Unsplash photographs in Safari, then approved for every previous landscape placement in the app and website. The shared native asset and public pages use a 2400-pixel JPEG export of this original. Both appearances use the same photograph on onboarding and secondary screens. The main tabs use their semantic backgrounds without decorative photography.

Both Home Screen widget sizes use a separate `WidgetLandscape` asset at 960 × 540 pixels as an edge-to-edge background, with a 60% black overlay and white text. WidgetKit archives the source image at its full pixel size even when SwiftUI displays it in a small frame. The 2400 × 1350 app image exceeded the archive limit and failed the timeline batch for both Home Screen widget sizes. Keep the widget derivative small when replacing the photograph; regenerate it from the app asset with:

```sh
sips --resampleWidth 960 ios/SharedResources/Assets.xcassets/Landscape.imageset/rice-lake.jpg --out ios/SharedResources/Assets.xcassets/WidgetLandscape.imageset/rice-lake-widget.jpg
```

- Photo: [Rice Lake, North Vancouver, BC, Canada](https://unsplash.com/photos/a-body-of-water-surrounded-by-a-forest-UyPumfejEMI)
- Photographer: [Kayvan Mazhar](https://unsplash.com/@kayvanmazhar)
- File: `rice-lake-kayvan-mazhar.jpg`, original download, 6000 × 3376 pixels, sRGB JPEG.
- SHA-256: `f8eef43a93626b24cfa9880542bb366b3fab09291842e1a733b2205a1e1b5816`
- License: [Unsplash License](https://unsplash.com/license), verified on the photo page and license page on the selection date. Free commercial use is permitted. Suggested credit: “Photo by Kayvan Mazhar on Unsplash.”

The forest and reflections naturally fit Kvil's deep green canvas (`#142D29`), green ink (`#244238`), and green accent (`#456B51`). Soft mist separates the trees without a bright, saturated sky. The still water gives the image a calm focal area. It is especially suitable beside the dark palette; warm ivory (`#F8F5EB`) provides a clear surrounding surface in light mode.

Keep photography off the Home, Schedule, and History tabs so the content has the available space. Home is centered between the navigation and tab bars and does not scroll; a compact layout opens reflections in a sheet when they cannot fit inline. Avoid a canvas-colored fade over the treetops: it washes out the image in light mode. The Home Screen widgets place text over the darkened photograph; system-tinted and background-free contexts retain native adaptive colors. There is a small distant viewing platform with visitors near the center shoreline; account for that detail when choosing a crop. Export a smaller derivative for shipping and keep this download as the source.

Also reviewed: [Nathaniel Shuman's misty mountain lake](https://unsplash.com/photos/a-lake-surrounded-by-trees-40iZ4eRZ5k8), a brighter alternative with more open sky and warmer yellow-green vegetation.
