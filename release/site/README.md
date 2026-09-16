# Kvil public pages

Kvil's [overview](https://hkarlsen06.dev/kvil/), [support](https://hkarlsen06.dev/kvil/support/), and [privacy](https://hkarlsen06.dev/kvil/privacy/) pages are hosted in the existing portfolio. The canonical repository is `mdr:/home/hkarlsen06/code/hkarlsen06.dev`, remote `hkarlsen06/hkarlsen06.dev`, under `public/kvil/`. Cloudflare Pages project: `hkarlsen06-dev`.

## Published policy update: 15 September 2026

The privacy and support articles now match `release/privacy.md` and `release/support.md`: encrypted private CloudKit schedule sync, fasting adjustments, legacy KVS migration, current Health authorization, and backup consent. Both public URLs and the deployment URL returned 200, with exact article matches. Cloudflare email protection was normalized when comparing complete HTML. [Publication evidence](../privacy-site-verified.json).

The current production source was commit `8a2d5928baa0cb2ff6479d55b8955e676600519c`. An isolated archive of that commit received only the two article replacements. Its locked dependencies, production build and TypeScript checks passed. The complete 130-file export was published as [7e75a446](https://7e75a446.hkarlsen06-dev.pages.dev), on Production/main. Before-and-after checks preserved visible text on 15 other HTML pages and exact bytes for 24 assets.

The canonical repository received the same article updates. Its unrelated files and Git index were hash-checked and preserved. Nothing was committed or pushed. A later Git-triggered deployment can replace a direct upload unless the updated source is included.

## Release snapshot and earlier artwork

`dist/kvil/` is a working snapshot. Its privacy/support article bodies are current, but its headers, favicon links, overview, styles and images retain the earlier photography revision. They are not a complete snapshot of the current public site. The 14 September Git deployment had restored older production artwork; this policy-only publication preserved that production layout and excluded the canonical repository's unrelated visual edits.

`../photography-verified.json`, `../website-verified.json`, and `../favicon-verified.json` retain historical deployment evidence. Their visual results do not describe the current production layout. Refresh and review the overview and artwork separately before publishing those changes.

The authored Kvil pages contain no JavaScript, analytics, forms, or external fonts. The existing Cloudflare email-protection feature transforms public email links and adds its decoding script. The snapshot follows system appearance and contains the licensed Rice Lake photograph and its attribution.

Preview the snapshot with `python3 -m http.server 8765 --bind 127.0.0.1 --directory release/site/dist`, then open `http://127.0.0.1:8765/kvil/`. This does not preview the whole portfolio.

## Future publication

Inspect the latest Production deployment and canonical working tree before choosing a build source. Build and deploy the entire portfolio export; do not publish the Kvil-only snapshot as the portfolio root. Preserve unrelated changes and compare their public pages/assets before and after deployment.

The established workflow is `bun install --frozen-lockfile`, `bun run build`, then authenticated `wrangler pages deploy <complete-out-directory> --project-name hkarlsen06-dev --branch main`. For an isolated build, provide the matching portfolio `--commit-hash` and an explicit `--commit-message` so Wrangler does not try to infer metadata from another repository. Record actual production readback separately from a successful build or upload.
