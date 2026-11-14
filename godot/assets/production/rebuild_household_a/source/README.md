# Household props

Six original meshes: continuous skirted toilet, hollow mug, turned rolling pin, cast iron pan, rubber plunger and straw broom. Old GLBs are retained. Source reference photos are used for construction only; no source images are bundled as textures.

References:
- Toilet: https://buhinnavi.lixil.co.jp/toilet/tost-09?keyword=BC-250S
- Mug: https://www.ikea.com/au/en/p/ikea-365-mug-white-60278368/ (blue glaze adapted for readability)
- Rolling pin: https://www.etsy.com/market/vintage_rolling_pins
- Pan: https://www.knivesandtools.es/es/pt/-lodge-classic-cast-iron-we-can-do-it-2020-made-in-america-logo-l-8skmia-sarten-26-cm.htm
- Plunger: https://www.elgiganten.se/product/hem-hushall-tradgard/verktyg-maskiner/diverse-verktyg/millarcoR-vaskrensare-med-traskaft-o-15-x-40-cm/609097
- Broom: https://www.princessauto.com/en/product/corn-brooms/PA1000002188/8240582

Toilet outside is one continuous shell from the floor to bowl. Plunger disposal label hangs on a paper tag to avoid clipping through the rubber cup.

## Lower polygon rebuild

Use Blender CLI `--background --factory-startup --python tools/build_lowpoly_props.py -- rebuild_household_a` from repository root. The low-poly driver caps radial subdivisions, keeps smooth curved normals and uses a single bevel segment. Generic source builder alone regenerates the denser authoring variant. Godot runtime provides authoritative paired previews and checks.
