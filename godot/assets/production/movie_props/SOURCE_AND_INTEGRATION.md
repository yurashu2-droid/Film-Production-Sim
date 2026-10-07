# Low-budget monster / witch hand props

API: preload("res://scripts/production_movie_prop.gd").new(); build_model("dragon_skull" | "witch_cauldron") before add_child; assign game/pid and register through stage._register as a normal Prop. Candidate initial locations: dragon (51, floor_y, 17), cauldron (54, floor_y, 19), within requested world49..57 / z14..22. Floor origin is normalized to the bottom of each source model. Dragon faces +Z in its original model hierarchy. Parent owns event/UI integration.

Both are movable/fixable using inherited Prop behavior; rolls=false, dragon foam-prop mass2.5kg, cauldron scenic-prop mass8kg. These are gameplay masses, not source physical measurements. Original Downloads files remain unchanged. No VFX added.

Dragon API: can_activate() true, set_active(on) rotates the existing jawPivot local X by an additional24deg while preserving original pivot transform and complete jawVisual/teethLower hierarchy. There are no source animation clips. No mesh vertices were modified. Off restores its original slightly-open pose, rather than forcing bones into an invented fully shut pose. Original horn pivots remain untouched. get_state adds active as index3; _apply_extra restores the same pose for sync, recording and inherited restore(). Broadcast F through host_ev and preserve the fourth state field.

Cauldron API: can_activate() false. Source has only world/geometry_0 (one combined mesh), no lid hierarchy and no animation, so it can be carried/fixed without geometry distortion. No opening behavior invented. Source has COLOR_0 vertices and no material; runtime StandardMaterial3D enables vertex_color_use_as_albedo, preserving dark pot / green liquid colours instead of Godot's default white. Source has no normals; its relatively flat shading is retained. All source mesh colours remain intact.

| File | Original Downloads source | SHA256 | Bytes / triangles | Raw bounds size m | In-game size m |
| --- | --- | --- | --- | --- | --- |
| dragon_skull.glb | lowpoly_dragon_skull_v2_hierarchy.glb | 4aaa4a0fa2b3629dabe560bce3d99196ddd8c8411a61d7fd79bcb3eb1337c61f | 295380 / 2468 | 4.943983,3.773735,6.756 | .512254,.391003,.700 |
| witch_cauldron.glb | witch_cauldron_rebuilt_v2.glb | 6d5d1f7290d0c5a87e593500b0cdd16ee82ebd7fec59a24185f30da0a75e2ad6 | 221492 / 10992 | 1.900,1.4828,1.720 | 1.000,.780421,.905263 |

Imported exact binary copies under movie_props; no external textures, rig clips or skins. Dragon has89 small mesh components; at this tiny triangle count one actor prop is appropriate, but bulk crowd scatter would cost draw calls. Cauldron is one mesh. LOD conversion was unnecessary and would compromise the jaw structure. Redistribution license not supplied with standalone Downloads GLBs; ownership/use follows user-provided asset provenance, third-party rights remain unverified.

Collisions: dragon small central BoxShape (70%width, full height,85%depth), cauldron small CylinderShape (radius36%of minimum horizontal extent, full height). They preserve visible horn/handle silhouettes while avoiding fragile detailed triangle collisions. Parent floor required. Holding positions use source-normalized bounds center and inherited hold_target/gravity/restore handling.

Godot4.7.2 actual compatibility render and production_movie_prop_testshot.gd passed: load both models, bounds/scales, exact original jaw hierarchy opening, open-state restore, cauldron activation no-op and inherited holder gravity behavior. PNGs: artifacts/production_movie_closed.png and production_movie_open.png. Collision outlines are visible. No editor UI or full regression suite used.
