# Kvil public pages

Published within the existing portfolio at [hkarlsen06.dev/kvil/](https://hkarlsen06.dev/kvil/), with [support](https://hkarlsen06.dev/kvil/support/) and [privacy](https://hkarlsen06.dev/kvil/privacy/) pages.

The canonical website repository is `mdr:/home/hkarlsen06/code/hkarlsen06.dev`, remote `hkarlsen06/hkarlsen06.dev`. Its `public/kvil/` directory contains these static pages. Both portfolio languages list Kvil through the existing project component and dictionaries. Cloudflare Pages project: `hkarlsen06-dev`.

**Unpublished update, 15 September 2026:** `dist/kvil/privacy/index.html` and `dist/kvil/support/index.html` now contain prepared copy for encrypted private CloudKit schedule sync, legacy KVS migration, current Health authorization, and backup consent. They match `release/privacy.md` and `release/support.md`. These edits have not been copied to the canonical portfolio repository or deployed, and do not describe the current live page as verified. Publish the final policy with the verified candidate and read it back from the public URL.

The rest of `dist/kvil/`, including the overview and image assets, remains a snapshot of the earlier published pages. Refresh the overview's app image and related copy against the new candidate before publishing that revision. There is no build step for this snapshot. Preview with `python3 -m http.server 8765 --bind 127.0.0.1 --directory release/site/dist` and open `http://127.0.0.1:8765/kvil/`.

The authored pages contain no JavaScript, analytics, forms, or external fonts. They follow system appearance using the bundled Rice Lake photograph by Kayvan Mazhar. All three pages credit the photographer. The hero, social preview, and phone capture use the same photograph as the app. The existing Cloudflare email-protection feature transforms public email links and adds its decoding script.

`../photography-verified.json` records the earlier photography deployment, live content and asset checks, and preservation of the existing portfolio favicon and Tidex artwork. `../website-verified.json` records the original deployment before that visual revision. Neither verifies the prepared CloudKit policy update. Stylesheet and phone-image URLs include content hashes to refresh visitors' cached assets; update these hashes when changing either file.

All three Kvil pages use `assets/icon.svg` as their scalable favicon, with a 32-pixel PNG fallback and a 180-pixel Apple touch icon. The SVG is copied from `design/artwork/icon.svg`; the PNGs and 256-pixel header/project icon are resized from its generated `design/artwork/icon.png`. Refresh these four website assets together after changing the source artwork. `../favicon-verified.json` records the latest deployed favicon links, content types, and asset hashes.

For future changes, edit the canonical portfolio repository and refresh this release snapshot. Build and deploy the entire portfolio export. Do not deploy this Kvil-only snapshot as the portfolio root. Preserve existing unrelated working-tree changes when committing; compare their published assets before deploying.
