# Interior furniture rebuild (14 assets)

Built independently from named objects and real photo construction references. The old GLBs supply only their transformed vertex envelopes; no old model images or geometry are reused as design references.

Photo reference studies:
- [Boston upright piano](https://www.alamomusic.com/products/boston-46-up118s-upright-piano-satin-oak-sn-b132256-used): cabinet, keyboard shelf, front legs, separate brass pedals.
- [Richmond pedestal basin](https://www.victorianplumbing.co.uk/old-london-richmond-traditional-1th-basin-and-comfort-height-pedestal): flared basin over narrow pedestal; continuous open bowl, tap deck and drain.
- [Restaurant wood booths](https://www.timeout.com/london/restaurants/the-connaught-grill-1): supported upholstered seats and backs around a pedestal table.
- [Wood folding-screen interior](https://design-milk.com/womens-clothing-boutique-delights-shoppers-with-a-setting-full-of-charm/): full-thickness frame and inset panels, alternating hinged folds.

Design decisions: visible board thickness and joinery; cabinet drawer/door gaps; shelf voids; full-thickness supported mattress and pillow; six-sided rails/hooks and 16-sided regular cylinders. Turned pedestal profiles use 24 sides; bevels use one segment. Materials are flat base-color PBR, no noise or textures. All mesh transforms baked into geometry before material batching/export. Exact old vertex bounds retained in Blender coordinates (Godot Y-up conversion is handled by exporter).

`build_assets.py` writes 14 GLBs in the existing scrap folder and records replacements/counts/bounds locally. `preview.py` creates grouped front/rear studio previews from exported GLBs. Markers are omitted on these bag-spawned props. Blender geometry checks enforce finite coordinates, matching envelopes and <=4500 triangles. Engine appearance/colliders are reviewed by the parent integration workflow; these builders do not modify/import Godot data.
