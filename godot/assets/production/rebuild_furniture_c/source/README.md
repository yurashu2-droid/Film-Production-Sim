# Outdoor/scenic furniture rebuild (22 assets)

Construction-led independent low-poly rebuilds. Named-object photo studies:
- [Italian sidewalk newsstand](https://crema-news.it/pubbliredazionale/edicola-in-affitto): overhanging canopy, sheltered service opening, front publication displays.
- [Rialto wooden bridge](https://www.archiexpo.com/ja/prod/braun-wuerfele/product-124751-1220251.html): transverse decking carried by curved stringers, separate post-supported handrails.
- [Cedarshed arched bridge](https://cedarshed.com/products/8-ft-garden-bridge-with-side-rails): gentle deck arch, open underneath, actual end contacts.
- [Campania garden fountains](https://campaniainternational.com/collections/all-fountains): tiered open bowls carried by a central turned column.

The street/scenic set uses distinct structural parts: lamp post/lantern, cabinet slot/collection door, open picket/iron fences, wells with genuinely hollow shafts, roof posts and winding axle, open-front shelter with inset timetable, real market stall counter and supported canopy, broad brick courses, piles beneath dock decking. Water is opaque reflective scenery; fire is rigid painted scenic flame silhouettes (no VFX system). Broadleaf tree has three branch directions and grouped foliage lobes; pine has scalloped bough layers; cactus has rounded raised branches and broad ribs; hedge arch retains a real walk-through opening.

Standard cylinders use 16 sides, turned main profiles 24, rails/hooks six-sided sections, bevels one segment. No micro screws, textures, dense grids or noise. Export meshes bake matrix_world to identity before material batching. All 22 compare true transformed vertex bounds with the prior current model. This preserves normalized size and legacy collider compatibility without trusting old local object dimensions.

Eight nonbag props carry identity DisposalTicketAnchor markers on actual flat front-facing support: kiosk kickboard, streetlamp collar, bridge end fascia, mushroom/cactus/tree stem patch, campfire base plaque, fountain base plaque. Bag props omit markers. Parent performs Godot imports, runtime sticker/physics/appearance checks and integration; this packet does not change shared tables.

Run Blender background with this builder; mappings and counts/bounds are in replacements.json and build_manifest.json. The shared ../rebuild_furniture_b/source/preview.py renders contact sheets from the exported GLBs. The eight main scenic pieces retain the old full envelope; local interior landmark positions may differ and remain a specific runtime review point.
