# Kvil public pages

Published within the existing portfolio at [hkarlsen06.dev/kvil/](https://hkarlsen06.dev/kvil/), with [support](https://hkarlsen06.dev/kvil/support/) and [privacy](https://hkarlsen06.dev/kvil/privacy/) pages.

The canonical website repository is `mdr:/home/hkarlsen06/code/hkarlsen06.dev`, remote `hkarlsen06/hkarlsen06.dev`. Its `public/kvil/` directory contains these static pages. Both portfolio languages list Kvil through the existing project component and dictionaries. Cloudflare Pages project: `hkarlsen06-dev`.

`dist/kvil/` is a release snapshot of the published pages. There is no build step for this snapshot. Preview with `python3 -m http.server 8765 --bind 127.0.0.1 --directory release/site/dist` and open `http://127.0.0.1:8765/kvil/`.

The authored pages contain no JavaScript, analytics, forms, or external fonts. They follow system appearance using bundled artwork. The existing Cloudflare email-protection feature transforms public email links and adds its decoding script; verification normalizes only that known transformation. `../website-verified.json` records live content and asset checks, including the existing Tidex artwork.

For future changes, edit the canonical portfolio repository and refresh this release snapshot. Build and deploy the entire portfolio export. Do not deploy this Kvil-only snapshot as the portfolio root. Preserve existing unrelated working-tree changes when committing; compare their published assets before deploying.
