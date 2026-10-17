# Furniture reconstruction batch A (2026-10-17)

Eight original authored replacements for S026–S033. The old GLBs are retained.
The mapping is in `replacements.json`; game catalog and collider files are not
modified by this batch. Blender authoring is Z-up, front -Y; glTF converts to
Godot Y-up, front +Z. Every new asset is centered in XY and grounded at Z=0.

## References and provenance

The following actual furniture photographs were found with web image search,
downloaded to ignored `artifacts/rebuild-furniture-a/references/`, and inspected
together. These inform construction and material behavior; no photograph,
third-party mesh, brand mark, or product text is included in the deliverables.
No original asset thumbnail was used as an image-generation input. Image
generation was not used. Hidden/rear construction is authored inference.

| Replacement | Photograph/page | Construction decision |
|---|---|---|
| Director chair | [Newformsdesign Regista Fellini](https://www.newformsdesign.com/en/products/folding-chairs/folding-chair-director-regista-version-f_1931.php) ([photo](https://www.newformsdesign.com/images/prodotti/1576-20-regista-d-11-sedie-maneggevoli.jpg)) | Front/rear crossing timber supports, exposed pivots, locking braces, supported canvas seat/back and actual 4 mm cloth edge; shallow sag begins at sewn dowel sleeves. Original taller chair silhouette retained. |
| Two-seat sofa | [IKEA KLIPPAN](https://www.ikea.com.tw/zh/products/sofas/sofas/klippan-spr-49010615) ([photo](https://www.ikea.com.tw/dairyfarm/tw/images/399/0239990_PE379591_S5.jpg)) | A joined lower deck supports full side panels and back shell. Two seat/back cushions have broad tailored panels, edge rolls and sewn welts. Petrol fabric and timber feet are original choices. |
| Wing armchair | [STRANDMON leather chair](https://www.carousell.sg/p/ikea-strandmon-leather-wing-chair-dark-brown-1377958861/) ([photo](https://media.karousell.com/media/photos/products/2025/7/1/ikea_strandmon_leather_wing_ch_1751336279_e6743fe6_progressive.jpg)) | One continuous tapered high back with forward-swept shoulder wings; shaped supported side arms, separately sewn cushion, covered buttons, restrained tack row, tapered timber feet. Oxblood finish inferred. |
| Swivel bar stool | [Detroit American Diner Bar Stool](https://www.barstools.co.uk/detroit-bar-stool-red.html) ([photo](https://www.barstools.co.uk/media/staempfli_imageresizer/cache/catalog/product/d/e/1100x1100_co_ar_tr_85/detroit_bar_stool_red_seat.jpg)) | Revolved dished metal pedestal, rubber floor rim, telescoping stem, seat skirt and one padded seat; footring attaches through three radial spokes. A low lumbar rest is inferred to preserve the original asset's overall tall/low-back proportions. |
| Dining table | [Stickley Gable Road](https://www.stickley.com/products/gable-road-62-inch-dining-table) ([photo](https://www.stickley.com/cdn/shop/products/713-916-802_GableRoad62inchDiningTable_Angle.jpg?v=1668714627)) | Full-thickness joined wood top, four tapered legs, four recessed aprons and underside diagonal corner blocks. Grain follows each board/leg's long axis. |
| Writing desk | [Vintage Thomasville writing desk](https://www.ebay.com/itm/396979493722) ([photo](https://i.ebayimg.com/00/s/MTE0MlgxNjAw/z/KvYAAeSwGAlopnEF/$_57.JPG?set_id=880000500F)) | Two supported drawer pedestals and an open kneehole preserve the original envelope. Separate inset drawer fronts, visible reveal gaps, raised panels, brass hanging handles and a framed green leather writing inset. |
| Bar counter | [Footrail Store customer gallery](https://www.thefootrailstore.com/gallery.html) ([photo](https://www.thefootrailstore.com/uploads/6/5/2/1/65218015/satin-brass-pic.jpg)) | Continuous paneled cabinet face with structural stiles, recessed panels and molding; overhanging thick top, rear shelving/dividers, and one brass footrail secured with three brackets. |
| Single bed | [Old Creamery oak single bed](https://www.oldcreameryfurniture.com/countryside-lite-30-low-foot-end-bed-frame/p792) ([photo](https://www.oldcreameryfurniture.com/images/products/large/792_4592.jpg)) | Posts/side rails/cleats support fourteen slats, a real mattress, fitted sheet, separate filled pillow and a resting coverlet with two short side drops. Slatted headboard is joined to full-height rear posts. |

The source pack `film_crew_large_sets_batch02_S026_S050.zip` in the original
workspace's `小道具大道具(仮)/` was inspected for its README and license. Its
original meshes were used only to measure each transformed bounding envelope.
Its license permits editing/replacement and redistribution in this project.

## Construction and materials

This batch applies `model-stylized-materials` and its cloth, wrinkle, leather,
and painted-wood modules. Upholstery uses closed rounded-rectangle contour
shells with broad shaped panels, thickness and slight localized compression;
it is static authored geometry, not a cloth simulation. Arms and wings are
supported continuous side/back shells rather than disconnected ellipsoids.
Timber edge radii stay small (usually 2–5 mm), preserving planar spans.

Wood textures are original deterministic baked long-grain images generated by
the builder and packed in each GLB. They have quiet color variation and do not
depend on Blender procedural nodes at runtime. Cloth/leather/vinyl use normal
glTF metallic-roughness PBR base colors and roughness. Geometry carries the
meaningful seams, thickness, support and shadow gaps. No external texture files
are required. Fine fiber/leather pores are deliberately omitted at game scale.

Each model is fitted to the existing transformed model's XYZ dimensions to
preserve normalization behavior and fallback collider proportions. The catalog
size/mass values are recorded in the manifest and are not changed. There are no
special `prop_shapes.gd` entries for these eight kinds. Small authored shape
differences within the fitted envelope are intentional. Grounded geometry is
centered in XY; the original director chair's approximately 6 mm ground offset
is removed. The helper's `DisposalTicketAnchor` is retained for every asset.

## Rebuild and evidence

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/rebuild_furniture_a/source/build_assets.py
```

An optional `-- S028_wing_armchair` selects an asset and updates its existing
manifest row. The helper module is loaded with a unique import name. Material
batches are joined before GLB export to bound runtime draw calls. The builder
checks finite mesh coordinates, degenerate polygon area and closed authored
shells after welding coincident curve-cap vertices. It then saves editable
`.blend` files and matched front/rear studio renders to the ignored
`artifacts/rebuild-furniture-a/` folder. This does not touch `.godot/`.

Godot import, game rendering, carrying/collision behavior and final acceptance
are parent-owned and not certified by the Blender checks. No new test suite or
test cases are added for this asset-authoring task. The builder's checks are
bounded mesh/export verification, not physical load-bearing certification.

## Current lower polygon build

User requested a simpler polygon style. Run Blender CLI `--background --factory-startup --python tools/build_lowpoly_props.py -- rebuild_furniture_a` from repository root. This caps cylinders at 16 sides, turned bodies at 24, small tubes at 6, ellipsoids at 16 by 8, and bevels at one segment. Preserve recognizable construction, silhouette and openings. Generic builder alone generates the denser source variant. Current triangle counts are in build_manifest.json.
