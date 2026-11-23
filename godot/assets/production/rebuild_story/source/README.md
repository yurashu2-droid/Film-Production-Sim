# Adventure and comedy props — lower polygon group

Nineteen original replacement meshes. The old GLBs are kept. Construction follows physical reference photographs, with no old image supplied to image generation. Procedural material colors only; no downloaded reference image is redistributed.

Reference photographs inspected:
- Rubber duck: https://www.museumofplay.org/toys/rubber-duck/ — continuous body/neck, separated bill lips, small molded wings and eyes.
- Brass compass and collapsible telescope: https://www.nauticalplace.com/listing/194992921/brass-telescope-compass-gift-set-w — nested barrels, inset lenses, compass needle/ticks.
- Sword, shield and leather gear: https://www.wilson55.com/auction/lot/lot-171---replica-of-a-viking-broadsword-also-a-small/?lot=194309&sd=1 — broad blade planes, central shield boss, rear grip and bracing.
- Cream pie: https://propsamerica.com/proddetail.asp?prod=PIE109 — shallow pie tin, pastry rim, broad filling and sparse whipped topping.
- Comedy rubber chicken: https://www.ebay.com/itm/232364965570 — long neck, attached comb, loose legs and molded vinyl body; color simplified.

Gold-painted owl, the novelty rubber coil and other printed/fantasy details are original authored interpretations: broad newspaper columns, map island and route, blue bound spellbook, red wax seal, corked bottle, five-point wand and leather satchel. No third-party logos. Hidden backs are inferred from construction.

Lower-poly contract: 12–24 radial segments; one edge bevel; detail in major parts rather than tiny decoration. Duck/chicken bodies have a joined and simplified continuous molded shell; no animation or soft-body response is claimed. Old transformed vertex envelopes are measured only to retain gameplay proportions. Fit and object rotations are baked before export so Godot measures grounded meshes correctly.

Rebuild: Blender CLI `--background --factory-startup --python-exit-code 1 --python godot/assets/production/rebuild_story/source/build_assets.py`. Author Z-up/front -Y; glTF exports Y-up/front +Z. Actual counts/bounds in build_manifest.json; parent-owned Godot review is recorded in the main manifest.
