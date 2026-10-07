# Production integration notes

`preload("res://scripts/production_assets.gd").decorate(parent, area)` accepts `office`, `scrapyard`, `studio`, `yard`, returns one Node3D root. All placements are local to area centre and scale 1. Parent provides floor. No gameplay is wired. Studio is 8 by 10 m inside; keep enough area clear. Office retains supplied control desk and storage rack at their authored positions. Studio roof/south frontage/doors are hidden for camera access; west/east/north wall collisions are coarse boxes. Props have simple fixed body proxies. Remove those proxies before converting a decorative model to a movable RigidBody3D. Yard closed shutter proxy must be disabled when opening; animation does not drive collision.

Measured Godot4.7 initial rendered mesh bounds (X,Y,Z metres):

| GLB | Size | Imported animation names |
| --- | --- | --- |
| studio.glb | 8.440,5.188,10.497 | none |
| cleaning_cart.glb | 1.187,1.490,0.644 | Wringer |
| lift_cart.glb | 1.246,0.951,0.520 | Lift |
| hose_reel.glb | 0.349,0.446,1.205 | HR01_Extend_Hold_Retract |
| shutter.glb | 4.086,3.803,0.907 | Close,Closed,Half_Open,Open,Opened |

Cleaning cart is best for a push/carry filming prop; wringer is cosmetic and bucket/trays/mop are separate operation units. Lift cart is a moving camera platform candidate: Lift raises table about 0.44 to 1.00 m, but standing/contact collision needs gameplay integration. Hose reel is a fixed wall prop and authored hose-extension animation, not a freely dragging physics rope. Shutter is a 3.2 by 3 m opening candidate; five clips preserve rig. Godot shortens source names Wringer_Cycle and Lift_Cycle to Wringer and Lift. Use actual AnimationPlayer list.

All maps are embedded and materials rendered correctly in the Godot4.7 compatibility screenshot `artifacts/production_assets.png`. Shutter/lift use source LOD1. Hose has 129k triangles and 184 meshes; use one close-up instance, avoid repeated scatter. Sources remain unchanged in Downloads. No full source packages, Blender files, or redundant loose textures imported. SOURCE.md records exact package members and hashes plus rights caveat.

Validation: headless console import succeeded; production_asset_testshot.gd loaded all five GLBs, measured bounds and clip names, constructed all four decoration areas and rendered scrapyard screenshot. No engine editor UI used. Main gameplay regression suite belongs to parent integration.
