# Prop rebuilding

## Current lower polygon build

User requested a simpler polygon style. Run Blender CLI `--background --factory-startup --python tools/build_lowpoly_props.py -- rebuild_small_b` from repository root. This caps cylinders at 16 sides, turned bodies at 24, small tubes at 6, ellipsoids at 16 by 8, and bevels at one segment. Preserve recognizable construction, silhouette and openings. Generic builder alone generates the denser source variant. Current triangle counts are in build_manifest.json.
