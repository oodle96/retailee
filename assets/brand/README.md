# Retailee original asset set

Direction: familiar warung objects drawn with a consistent ink outline, warm paper, violet, sage and ochre. No gradients, fake charts, floating stars or stock characters. The supplied purple storefront remains the identity reference; its awning and friendly expression are simplified for small sizes. The separate illustrations carry the notebook, inventory and receipt context instead of packing everything into one mascot.

## Editable source
- lib/widgets/brand.dart: small storefront mark and native wordmark.
- lib/widgets/retail_art.dart: four original CustomPainter vector illustrations on a 240 x 180 grid. All geometry, strokes and colors are editable; no downloaded artwork is embedded.

## Exports
- assets/illustrations/notebook.png: 720 x 540 transparent PNG, login.
- assets/illustrations/capture.png: 720 x 540 transparent PNG, scan guidance.
- assets/illustrations/shelf.png: 720 x 540 transparent PNG, first-stock empty state.
- assets/illustrations/receipts.png: 720 x 540 transparent PNG, empty report.
- assets/brand/retailee-launcher.png and Android/web icons: rendered from the new mark.
- qa/screenshots/retail-asset-sheet.png: overview for review.

The live app uses the vector painters so artwork remains sharp at any size; PNGs are provided for reuse. Regenerate illustration exports with flutter test qa/art_export_test.dart. Regenerate launcher exports with flutter test qa/ui_test.dart.

## Usage
Use one relevant illustration per guidance or empty state. Do not use illustrations as financial evidence or in place of the owner's actual photo. The figures in the artwork are blank ruled columns, not invented business data. Navigation now uses the original line-icon family in lib/widgets/retail_glyph.dart. Product list glyphs suggest unbranded packaging from names; they are not product photos. Other standard action icons remain Material icons.

Original geometry created in this workspace; no third-party illustration licensing or runtime network dependency was added. Existing Roboto and Material icon notices remain in this directory. The owner-supplied identity reference remains unchanged and is not a newly sourced asset.
