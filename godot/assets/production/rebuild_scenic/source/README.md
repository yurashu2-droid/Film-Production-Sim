# Large scenic props — lower polygon group

Fourteen original miniature vehicles and scenic props. Reference photos inform visible major construction; hidden rear returns/supports are authored interpretations. No downloaded images or copied logos are bundled.

References:
- Preserved Japanese bus photographs, front grille, split windscreen, headlamps and bumper: https://www.uraken.net/rail/travel-urabe475.html
- Vintage bus and locomotive construction: https://www.oldtimerbus-sonja.de/
- Dutch windmill / wooden boat photographs: https://www.tapeciarnia.pl/tapeta-lodki-nad-rzeka-z-wiatrakiem-w-tle

Sparsely modeled primary features include crane lattice and hanging hook; supported clock case and hands; capsule pressure shell/hatch; boiler/cowcatcher/headlamp; mill lattice sails; open rowboat hull/thwarts/plank courses; rickshaw wheels and canopy; waterwheel paddles; three-arm ticket turnstile. Paper mountain and bicycle retain the game's handmade scenic identity, with finite thickness and supporting feet. The clock cabinet, capsule details, rickshaw and reader layout are original generic interpretations, not replicas.

The old transformed vertex envelopes are preserved for gameplay. Mesh rotations and fitting are baked so runtime mesh bounds do not inflate rotated local boxes. Non-bag ticket markers face front without added rotation. 16–24 radial subdivisions, broad panels, one edge bevel. Detailed assemblies remain under 4,500 triangles; no hidden mechanical innards.

Rebuild: Blender CLI `--background --factory-startup --python-exit-code 1 --python godot/assets/production/rebuild_scenic/source/build_assets.py`. Uses the sibling rebuild_story helpers and envelope measurements. Author Z-up/front -Y; export glTF Y-up/front +Z. Actual counts/bounds in build_manifest.json.
