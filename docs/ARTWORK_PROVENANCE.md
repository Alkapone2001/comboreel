# Original artwork provenance

The offline catalogue artwork and ComboReel app icon were created for this
repository on 2026-08-19 with OpenAI's built-in image-generation workflow. No
third-party photographs, celebrity likenesses, franchise marks, stock assets, or
competitor logos were supplied as references. Outputs contain no embedded title
text so localized, accessible UI remains native Flutter text.

## Catalogue assets

| Fictional series | Final asset | Creative brief summary |
|---|---|---|
| Bound by a Secret | `bound-by-a-secret-poster.jpg`, `bound-by-a-secret-hero.jpg` | Rain-darkened mansion, fictional adult heiress and protector, sealed family photograph, burgundy/plum romance-mystery lighting |
| Stolen Vows | `stolen-vows-poster.jpg` | Non-intimate formal negotiation between fictional adult corporate rivals in an empty luxury ballroom, wine/antique-gold palette |
| The Alibi | `the-alibi-poster.jpg` | Fictional adult detective examining a photograph in a midnight evidence room, teal editorial-noir palette |
| Second Chance CEO | `second-chance-ceo-poster.jpg` | Fictional adult executives separated by a glass reflection at dawn, old promise card and company badge, amber/cocoa palette |

Every final prompt required wholly original adult faces, no resemblance to a
celebrity, no readable text, logo, watermark, weapon/gore, or existing franchise.
The portrait masters were prepared as 768×1152 JPEG at quality 86; the featured
hero is 1600×900. `tool/prepare_artwork.dart` documents the deterministic export
path. The generated app-icon brief and derivative process are recorded in
`store/ASSETS.md`.

## Production use

These assets make offline previews and automated screenshots coherent; production
catalogue rows may override them with `poster_url` and `hero_url`. Before public
release, the operator must confirm that use of generated content complies with
the generator terms, store declarations, territorial rules, and internal brand
approval. Keep this file, source prompts, commit SHA, and final binaries as the
content-rights evidence bundle.

## Licensed demo title

`sintel-poster.jpg` and `sintel-hero.jpg` are unaltered-frame compositions
extracted from the official *Sintel* master published by the Blender Foundation.
The film, stills, and subtitles are reused under Creative Commons Attribution
3.0. The official reuse terms permit commercial redistribution and require the
complete film credit scroll when the film itself is screened. ComboReel keeps
that scroll intact in episode 9 and identifies the adaptation in catalogue copy.

- Creator: Blender Foundation / Durian Open Movie Project
- Official project: https://durian.blender.org/
- Official licence terms: https://durian.blender.org/sharing/
- Licence: https://creativecommons.org/licenses/by/3.0/
- Source master: `sintel-1024-surround.mp4`, 129,241,752 bytes
- Source SHA-256: `1DC6F2CA9762DFCC7D1B1843129A3E4F351D1FE935DEA2241C7B359C11EBC1D8`
- Adaptation notice: divided into nine playback chapters; vertical upload
  masters add a blurred-background 9:16 canvas without cropping the original
  widescreen frame.

The Blender and Durian logos are not used. `tool/prepare_sintel_demo.ps1`
reproduces the derived files and upload-ready episode masters from the official
source.
