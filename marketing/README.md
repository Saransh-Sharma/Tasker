# LifeBoard marketing

Launch films for LifeBoard and a catalog of the artwork in the app. Open `index.html` in a browser for the catalog: every film in
three formats with posters, contact sheets, beat sheets and the copy deck, plus every curated asset with its source path.

```
marketing/
  index.html                the catalog (generated; open it directly from disk)
  build-all.sh              curate assets, build the films, rebuild the catalog
  tools/curate-assets.mjs   copies app art into assets/ (max 1254 px) and writes manifest.json + manifest.js
  tools/build-catalog.mjs   scans teaser/out/final and the manifest, writes index.html
  assets/                   curated art by family (binaries gitignored; manifest committed)
  teaser/                   the films: "A real day, drawn" (see teaser/README.md)
```

## Rendering

Needs Node 18+, ffmpeg and a Chromium (defaults to Playwright's Chrome for Testing on this Mac; set `CHROME` to override).

```bash
bash marketing/build-all.sh                  # assets, 4 cuts x 3 formats, catalog
bash marketing/teaser/build.sh advert-30s    # one film
node marketing/tools/build-catalog.mjs       # after any render
```
