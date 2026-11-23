# Equipment props A — 2026-10-17

Eight independently constructed, photo-informed production props. The existing
P053–P062 GLBs are retained. `replacements.json` is the integration handoff;
`production_scrap.gd` has not been edited by this builder. Its target sizes/masses
are copied into `build_manifest.json` as read-only integration constraints.

## References and construction decisions

All references were found through web image search, using real product photographs.
They are visual reference only: no photo, logo, trademark lettering, source model,
or external texture is embedded. Original game thumbnails were never image-generation
inputs. No image generation was used. Hidden construction is an authored inference,
and these are unbranded stylized props, not exact commercial product replicas.

| Prop | Photo reference | Retained construction cues |
|---|---|---|
| P053 walkie talkie | [Icom IC-F1000 family](https://www.wattscom.com.au/products/ic-f1000-compact-ip67-waterproofing-vhf-radio) | Tapered shoulder housing; separate rear battery/heel; belt clip; molded grip ribs; side PTT; speaker grille; LCD; top volume knob and tapered antenna. |
| P054 single-ear headset | [Clear-Com CC-110](https://www.audiomasterpiece.com/clear-com/clear-com-cc-110-headset) | Continuous steel band; padded crown; sliding rail; two metal yoke forks connected to cup pivots; opposite temple rest; connected boom with foam windscreen; attached lead and plug. |
| P055 closed headphones | [Beyerdynamic DT770 physical construction](https://www.head-fi.org/threads/the-mod-collective-bring-all-your-full-sized-headphone-mods-here.867426/page-4) | Two closed cups; recessed acoustic cloth; thick oval velour cushions with open centers; continuous band; yokes/pivots and cable connection. |
| P058 cylindrical lens case | [Lowepro 9x13 lens case](https://www.camaralia.com/es/9345-lowepro-lens-case-9x13-cm.html) | Hollow padded cylindrical wall; inner warm lining; bound seams and zipper; supported carry loop; fabric hinge and open padded lid. A generic seated lens adds layered barrel/focus/front rings and a recessed blue optical surface. Open lid and orange lining are authored choices. |
| P059 tabletop tripod | [Manfrotto PIXI](https://www.camerawholesalers.com/products/manfrotto-mtpixi-b-pixi-mini-tripod-black-1) | Three sculpted tapered legs connected to central hub and hinge pins; grounded rubber feet; ball joint; locking button; camera plate, pad and mounting stud. |
| P060 portable recorder | [Zoom H4n Pro](https://shop.solotech.com/products/zoom-h4n-pro-handy-audio-recorder) | Tapered rubber sleeve and control deck; backlit meters; red record/transport buttons; rear battery door; side wheel; two connected XY microphone capsules with supported grille rings; bottom combo inputs. |
| P061 field mixer | [Sound Devices 302](https://www.globalmediapro.com/dp/A2DQ00/Sound-Devices-302-3-channel-Field-Audio-Mixer/) | Sturdy metal body, protective grab rails, three input channels, tactile contrasting caps, twin meter banks and XLR sockets. Top controls and physical linear faders are a generic compact-mixer interpretation rather than an exact 302 layout. |
| P062 monitor | [SmallHD 702 Lite front/back photos](https://www.filmtools.com/smallhd-702l.html), [battery sled/connector rear view](https://kameristas.lt/products/smallhd-702-lite-7-ekranas-su-sdi-ir-hdmi-jungtimis-nuoma) | Stepped bezel and recessed screen; bottom controls; rear dual battery sleds/rails and release catches; BNC/HDMI ports; side pivot knobs; connected U-yoke and foot. Freestanding U-yoke is an inferred support choice. |

The existing source pack at
`小道具大道具(仮)/film_crew_small_props_P051-P075_v01.zip` was inspected,
including `README_ja.md` and `LICENSE.txt`. Its reusable originals are already the
game's current assets; this deliverable replaces their geometry quality rather
than adding a duplicate copy from the same pack. Its license permits editing and reuse.

## Materials and game scale

Molded shells use broad smooth planes, deliberate panel splits, physically thick
grips and supported interfaces. Roughness separates rubber, fabric/velour, metal,
control plastic and optical surfaces. Details are deliberately coarse enough to
read at small game scale: no microtext, logos, scratches or procedural noise.
Lens/screen glass is intentionally opaque blue-grey PBR with modeled reflection
accents, avoiding transparency sorting. All other materials use ordinary glTF
metallic/roughness PBR. No procedural texture or unsupported shader is required.

Authoring is Blender Z-up, front -Y; standard GLB export converts to Godot Y-up,
front +Z. Existing target normalization and mass values are unchanged. The meshes
are static, independently closed/intersecting construction components grouped by
material, not one Boolean union. Lens case is intentionally hollow; pads are rings.

## Regenerate and inspect

Run in an isolated process:

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python 'godot/assets/production/rebuild_gear_a/source/build_assets.py'
```

Uses the existing fresh/refined prop helpers by unique import name. Writes only
the eight `_rebuilt.glb` files plus this source folder's manifests. Editable scenes
are in ignored `artifacts/rebuild-gear-a/`. Generated geometry has coincident lathe
poles collapsed, is checked for finite coordinates, and is batched by material.

`artifacts/rebuild-gear-a/qa.py` reimports each exported GLB, checks finite geometry
and nonzero triangle area, and renders matching front/rear studio views. Results
are in `roundtrip_audit.json` and `*_front.png` / `*_rear.png` in that same folder.
All eight GLBs passed that round trip: finite coordinates, zero zero-area triangles,
and triangle counts matching the export manifest. All sixteen front/rear studio
renders were visually reviewed; `contact_front.png` / `contact_rear.png` collect them.

Godot import, gameplay camera review, collisions/physics, disposal-ticket sizing,
and integration remain with the parent task. No engine process or new tests were
started by this asset builder. No animation, real electronic function, optical
calibration or material deformation is implemented or claimed.

## Current lower polygon build

User requested a simpler polygon style. Run Blender CLI `--background --factory-startup --python tools/build_lowpoly_props.py -- rebuild_gear_a` from repository root. This caps cylinders at 16 sides, turned bodies at 24, small tubes at 6, ellipsoids at 16 by 8, and bevels at one segment. Preserve recognizable construction, silhouette and openings. Generic builder alone generates the denser source variant. Current triangle counts are in build_manifest.json.
