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
