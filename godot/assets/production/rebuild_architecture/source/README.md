# Low-poly scenic architecture rebuilds

23 replacements for the pending architecture domain. All geometry and material colors are authored here. No third-party photograph, texture or mesh is shipped.

## Build

Use Blender 5.2.2 in a disposable factory-startup process:

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/rebuild_architecture/source/build_assets.py
```

Identifiers after `--` rebuild a subset and retain the other mappings. `render_previews.py` makes small front/rear Workbench previews from saved authoring scenes. `validate_exports.py` reimports every delivered GLB and checks transformed bounds, marker rotation and nine points across the runtime 0.13 x 0.085 m sticker rectangle.

`measure_originals.py` uses the old GLBs solely to measure actual transformed vertex envelopes. `original_envelopes.json` retains the measurements. Diagonal beams and all mesh transforms are baked before fitting and again before export. Fitted bounds preserve the original minima/maxima, not the old meshes' local bounds. Authoring: Blender Z-up/front -Y. Export: Godot Y-up/front +Z. Ticket markers have identity rotation/scale and face outward front -Y. Collider/runtime source files are unchanged.

## Validation and limits

All 23 delivered GLBs reimport with maximum transformed bound error below 0.000001 authoring units. Build validation passes finite vertices, closed authored shells and nondegenerate faces. All 207 ticket rectangle ray samples have supporting geometry and positive clearance. Counts are recorded in `build_manifest.json`; detailed export checks are in `export_validation.json`.

Main turned column shaft: 24 radial sides. Circular openings/flanges and ordinary cylinders: at most 16. Small rods/tubes: six. Bevels: one segment. No tiny screws, modeled wood grain, rope fibres, random damage, fine wires or new texture maps. Final models range from 528 to 2332 triangles.

`artifacts/rebuild-architecture/` retains `.blend` authoring scenes and 384 px front/rear Workbench previews. All front/rear silhouettes were inspected. Porthole wall corners, fireplace mantel supports and sticker-support construction were corrected and re-rendered. Workbench previews verify shape/construction; Godot runtime and PBR appearance remain parent-owned checks. All models are static. Clear sash/porthole openings omit glass; shoji paper is opaque. Rear framing and hidden support details are inferred where photographs do not expose them. Identification plate/end fascia/gable gusset provide planar ticket contact while retaining the original envelope.

## Photographic construction references

Photos were consulted through real-photo image search; they remain at their publishers and are not redistributed. Reference reuse is intentional for shared construction. Scenic framing applies across the door, window, hatch, elevator and room-corner family. All proportions are adapted to each original game envelope; these are new interpretations, not exact reconstructions of photographed buildings.

- **F, scenic flats and staircase construction:** [Backstage flats photo](https://www.quia.com/jg/3202621list.html), image https://www.quia.com/files/quia/users/j0142/Scenery/Flats.jpg ; [Justin Fenniman theatre staircase photo](https://justinfenniman.com/flea.html), image https://justinfenniman.com/img/fleaSet_04.jpg . Timber frames, floor jacks, feet and light scenic skins.
- **A, masonry arches / broken arch / sewer surround:** [Serjilla gate photo](https://commons.wikimedia.org/wiki/File:Idlib,_Syria,_Dead_Cities,_Serjilla,_Gate.jpg) ; [Daman Fort partly collapsed arch photo](https://vmis.in/ArchiveCategories/collection_gallery_zoom?id=384&index=21631&search=1&searchstring=), image https://vmis.in/upload/Assets/Archive/384/8977.jpg . Broad radial voussoirs, imposts, ashlar courses and purposeful fractured ends.
- **C, column:** [Marc Maison Doric limestone columns](https://www.marcmaison.fr/Architecture-Exterieure/monumental-and-structures/paire-de-colonnes-cannelees-en-pierre-%E2%80%93-style-dorique-fin-xviiie-siecle), image https://www.marcmaison.fr/visuals/15840/_08_big.jpg . Turned mouldings, taper and square plinth; deep flute geometry omitted.
- **H, chimney:** [Rockford chimney crown photo](https://www.rockfordchimneysupply.com/blogs/chimney-caps-and-chase-covers/chimney-caps-chimney-covers-differences), image https://www.rockfordchimneysupply.com/cdn/shop/articles/deteriorating-brick-chimney.jpg?v=1690330994 . Hollow flue, broad rim and staggered masonry; crooked upper offset is an authored scenic exaggeration.
- **S, saloon:** [Palace Saloon real interior photo](https://www.bridgeandtunnelclub.com/bigmap/outoftown/arizona/prescott/thepalace/index.htm) ; [installed Craftsman saloon doors](https://www.swingingcafedoors.com/craftsman-western-swinging-saloon-doors-swinging-cafe-doors/). Scalloped tops, broad panel rails and double-action hinge locations; elaborate carving omitted.
- **G, barred gate:** [Old Montana State Prison photo](https://en.wikipedia.org/wiki/Montana_State_Prison), image https://upload.wikimedia.org/wikipedia/commons/2/2a/OMPSiberia.jpg . Open bars, lock plate and cross straps; gate construction reused behind sewer arch.
- **B, barn / timber portal / gable:** [Yankee Barn Homes Sutton Barn photos](https://yankeebarnhomes.com/2014/07/10/sutton-barn-lifestyle/) ; [real timber-frame barn interior](https://www.houzz.com/photos/middlesex-farmhouse-and-timber-frame-barn-farmhouse-garage-burlington-phvw-vp~64406182). Separate planks, knee braces, ties and rafters; fine grain and roofing corrugations omitted.
- **J, shoji:** [installed timber shoji-style door photo](https://www.pinterest.com/pin/barn-doors-with-a-shoji-style-the-glass-has-3m-rice-paper-pattern-film-called-yamato-the-doors-were-han--8796161750032176/), image https://i.pinimg.com/originals/b1/eb/93/b1eb939538262695c6c23e90cc41dded.jpg . Timber perimeter, sparse lattice and warm paper infill; outer scenic support inferred.
- **P, porthole:** [Linnaea Mallette porthole photo](https://www.publicdomainpictures.net/ru/view-image.php?image=275255&picture=), image https://www.publicdomainpictures.net/pictures/280000/nahled/porthole-15422145054o8.jpg . Plate, flange, gasket and large fastener rhythm; corrosion omitted.
- **W, serving hatch:** [Woodworkers Company installed bifold-window gallery](https://www.woodworkers.com.au/photo-gallery/window-galleries/bifold-windows-gallery). Supported serving ledge and pass-through; single raised scenic shutter is an authored simplification.
- **T, stairs / ramp / platform:** [Select Staging Concepts installed stage and ramp photo](https://educationhq.com/news/any-height-stage-or-platform-can-have-our-access-ramp-system-90967/) ; [CS LED portable staging photo](https://www.csledlighting.com/portable-staging). Broad treads, thin supported deck and continuous rails; trapdoor joinery inferred from stagecraft construction.
- **R, plank bridge:** [Treehouse Life installed River Brue rope bridge](https://rope-bridges.com/projects/rope-bridge-over-the-river-brue-castle-cary). Separate planks and gently sagging rails; scenic longitudinal supports retain original game envelope.
- **M, fireplace:** [Salvo rustic Italian stone fireplace photo](https://www.salvoweb.com/36638-large-rustic-antique-italian-stone-fireplace). Thick jambs, supported mantel and recessed firebox; ornamental carving omitted.
- **E, elevator:** [KU Leuven Herman Servotte elevator photo](https://www.kuleuven.be/kulag/en/gebouw/107-18), image https://res.cloudinary.com/td-applicatiebeheer-ku-leuven/image/upload/w_800/v1597608726/kulag_dev/BuildingPhotoId-744e38b9-d861-41ef-91c5-69bf9c430eea.jpg . Paired steel leaves, meeting seam, jambs, floor indicator and two large call buttons.

## Assets and simplifications

| Original identifier | Triangles | Ref. | Authored construction |
| --- | ---: | --- | --- |
| `S020_crooked_chimney` | 2080 | H | Staggered broad bricks, crooked throat, thick open coping and deep soot floor. |
| `S011_foam_column` | 612 | C | 24-sided taper, turned base mouldings, square capital/plinth; flute microgeometry omitted. |
| `S010_freestanding_arch` | 1100 | A | Radial voussoirs, five ashlar pier courses, imposts and retained through-opening. |
| `S001_hinged_door_wall` | 1580 | F | Raised-panel leaf, casing, knob and hinge barrels; rear timber frame and floor jacks. |
| `S002_saloon_swing_doors` | 1364 | S, F | Mirrored scalloped half doors, broad rails, vertical boards and strap hinges. |
| `S003_barred_cell_gate` | 1076 | G, F | Open six-sided iron bars, welded straps, broad lock and hinge barrels. |
| `S004_barn_double_door` | 1540 | B | Red separate planks, broad diagonal/horizontal timber braces, strap hinges and bent handles. |
| `S005_sliding_shoji` | 1564 | J | Thin opaque paper, sparse kumiko lattice, kick boards, finger pulls and tracks. |
| `S006_sash_window_wall` | 1296 | F | Two sash frames, four empty lights, projecting sill, brackets and scenic rear frame. |
| `S008_porthole_bulkhead` | 888 | P | Rectangular plate with genuine 16-sided hole, thick flange/gasket, eight broad bolts. |
| `S009_serving_hatch` | 1112 | W, F | Open pass-through, supported wide counter, raised shutter on two stays. |
| `S012_timber_portal` | 528 | B | Heavy lintel, square posts, knee braces, iron bindings and actual feet. |
| `S013_straight_stair` | 1496 | T, F | Seven tread/riser pairs, nosings, diagonal stringers, rear legs and rails. |
| `S014_turning_stair` | 2332 | T, F | Opposed four-step flights and connecting landing on grounded post/brace frame. |
| `S015_access_ramp` | 900 | T | Thin sloped deck, triangular side stringers, curbs, battens and steel rails. |
| `S017_trapdoor_platform` | 1120 | T, F | Stage deck around five-plank flush lid, broad hinges, horizontal pull ring and four legs. |
| `S018_plank_bridge` | 1456 | R | Thirteen planks, longitudinal supports, grounded posts and six-sided sagging rope rails. |
| `S019_gable_roof` | 1044 | B | Four folded roof courses per slope, rafters, ties, eaves and front triangular gusset. |
| `S021_scenic_fireplace` | 976 | M | Recessed firebox, radial stone arch, full-height jambs, deep hearth and broad mantel. |
| `S022_broken_arch` | 1168 | A | Asymmetric missing crown, fractured end blocks, stacked piers and two fallen blocks. |
| `S023_elevator_facade` | 1336 | E, F | Steel sliding leaves, meeting seam, broad recesses, threshold, numeral and two call buttons. |
| `S024_folding_room_corner` | 1228 | F | Original open L arrangement, two painted skins, rear studs, wainscot and three hinges. |
| `S025_sewer_entry` | 1200 | A, G | Deep arch, broad radial stones, threshold and visibly open iron gate behind the opening. |
