extends Node3D
# VFXを単体で眺めるスタジオ。現場（倉庫）と撮影カメラ、両方の明るさで確かめられる。
# `-- --shots` を付けて起動すると、各エフェクトのコマ並べ画像を tests/shots/vfx_review に書き出して終わる。
const Lib := preload("res://vfx/vfx_lib.gd")
const Explosion := preload("res://vfx/vfx_explosion.gd")
const Fire := preload("res://vfx/vfx_fire.gd")
const Smoke := preload("res://vfx/vfx_smoke.gd")
const Projectile := preload("res://vfx/vfx_projectile.gd")
const Lightning := preload("res://vfx/vfx_lightning.gd")
const Brawl := preload("res://vfx/vfx_brawl.gd")
const Mushroom := preload("res://vfx/vfx_mushroom.gd")
const Slam := preload("res://vfx/vfx_slam.gd")
const FirePillar := preload("res://vfx/vfx_fire_pillar.gd")
const Aura := preload("res://vfx/vfx_aura.gd")
const Ink := preload("res://vfx/vfx_ink.gd")
const Cursed := preload("res://vfx/vfx_cursed.gd")
const Tornado := preload("res://vfx/vfx_tornado.gd")
const FireTornado := preload("res://vfx/vfx_fire_tornado.gd")
const AuroraRefrain := preload("res://vfx/vfx_aurora_refrain.gd")
const BlackFlash := preload("res://vfx/vfx_black_flash.gd")
const BlackBolt := preload("res://vfx/vfx_black_bolt.gd")
const Water := preload("res://vfx/vfx_water.gd")
const WaterOrb := preload("res://vfx/vfx_water_orb.gd")
const BlackLightning := preload("res://vfx/vfx_black_lightning.gd")
const FlowForm := preload("res://vfx/vfx_flow_form.gd")
const InkDragon := preload("res://vfx/vfx_ink_dragon.gd")
const PunkHit := preload("res://vfx/vfx_punk_hit.gd")
const PunkSet := preload("res://vfx/vfx_punk_set.gd")
const PunkSpikes3D := preload("res://vfx/vfx_punk_spikes3d.gd")
const InkBarrage := preload("res://vfx/vfx_ink_barrage.gd")
const InkUndertow := preload("res://vfx/vfx_ink_undertow.gd")
const InkCross := preload("res://vfx/vfx_ink_cross.gd")
const InkBloom := preload("res://vfx/vfx_ink_bloom.gd")
const SoundBass := preload("res://vfx/vfx_sound_bass.gd")
const SoundEcho := preload("res://vfx/vfx_sound_echo.gd")
const SoundChime := preload("res://vfx/vfx_sound_chime.gd")
const WaterSlash := preload("res://vfx/vfx_water_slash.gd")
const WaterIce := preload("res://vfx/vfx_water_ice.gd")
const WaterManga := preload("res://vfx/vfx_water_manga.gd")
const WaterWave := preload("res://vfx/vfx_water_wave.gd")
const PxFlame := preload("res://pixel_vfx/px_flame.gd")
const PxBurst := preload("res://pixel_vfx/px_burst.gd")
const PxPortal := preload("res://pixel_vfx/px_portal.gd")
const PxTeleport := preload("res://pixel_vfx/px_teleport.gd")
const PxMeteor := preload("res://pixel_vfx/px_meteor.gd")
const PxLightning := preload("res://pixel_vfx/px_lightning.gd")
const PxFireWave := preload("res://pixel_vfx/px_fire_wave.gd")
const PxPlasma := preload("res://pixel_vfx/px_plasma.gd")
const PxWaterfall := preload("res://pixel_vfx/px_waterfall.gd")
const PxVortex := preload("res://pixel_vfx/px_vortex.gd")
const PxGravity := preload("res://pixel_vfx/px_gravity.gd")
const PxIceBreak := preload("res://pixel_vfx/px_ice_break.gd")
const PxPetals := preload("res://pixel_vfx/px_petals.gd")
const PxSonic := preload("res://pixel_vfx/px_sonic.gd")
const Px50:=preload("res://pixel_vfx/pack50/px50.gd")
const PxApotheosis:=preload("res://pixel_vfx/ultimate/px_apotheosis.gd")
const GeneratedInk := preload("res://vfx/vfx_generated_ink.gd")
const GenSilhouette := preload("res://vfx/vfx_gen_silhouette.gd")
const GenCurve := preload("res://vfx/vfx_gen_curve.gd")
const GenEmission := preload("res://vfx/vfx_gen_emission.gd")
const GenMesh := preload("res://vfx/vfx_gen_mesh.gd")
const GenFlow := preload("res://vfx/vfx_gen_flow.gd")
const GenErosion := preload("res://vfx/vfx_gen_erosion.gd")
const GenMaterial := preload("res://vfx/vfx_gen_material.gd")
const MotifSolar := preload("res://vfx/vfx_motif_solar.gd")
const MotifGeyser := preload("res://vfx/vfx_motif_geyser.gd")
const MotifJelly := preload("res://vfx/vfx_motif_jelly.gd")
const MotifFerro := preload("res://vfx/vfx_motif_ferro.gd")
const MotifSeed := preload("res://vfx/vfx_motif_seed.gd")

# [表示名, id, 繰り返しの間隔（秒）, コマ並べで撮る時刻]
var fx_speed := 0.4              # --speed=1 で、黒閃を等速で撮る（比較用。既定は 0.4 倍速）

const ITEMS := [
	["爆発（本番）", "explosion", 5.0, [0.6, 0.83, 0.9, 1.02, 1.2, 1.5, 2.1, 3.0]],
	["爆発（テスト発火）", "explosion_small", 3.0, [0.03, 0.1, 0.22, 0.4, 0.7, 1.1, 1.5, 2.0]],
	["旧・爆発（比較用）", "old_explosion", 3.0, [0.03, 0.1, 0.22, 0.4, 0.7, 1.1, 1.7, 2.2]],
	["炎", "fire", 0.0, [0.1, 0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8]],
	["煙（アニメ調）", "smoke", 0.0, [0.2, 0.5, 0.9, 1.3, 1.7, 2.1, 2.5, 2.9]],
	["煙（フラット）", "smoke_flat", 0.0, [0.2, 0.5, 0.9, 1.3, 1.7, 2.1, 2.5, 2.9]],
	["飛び道具・炎（直線）", "shot_fire", 2.4, [0.2, 0.42, 0.5, 0.65, 0.8, 0.98, 1.08, 1.3]],
	["飛び道具・秘術（曲線・加速）", "shot_arcane", 2.8, [0.3, 0.55, 0.8, 1.0, 1.2, 1.36, 1.46, 1.7]],
	["飛び道具・毒（溜めなし・外れ）", "shot_venom", 2.0, [0.03, 0.1, 0.2, 0.35, 0.5, 0.62, 0.72, 0.9]],
	["落雷", "lightning", 2.6, [0.08, 0.18, 0.22, 0.3, 0.36, 0.45, 0.6, 1.0]],
	["どたばた乱闘雲", "brawl", 4.0, [0.18, 0.42, 0.7, 1.1, 1.5, 1.84, 2.13, 3.3]],
	["参考動画・白熱火球と炎輪", "mushroom", 5.0, [0.10, 0.30, 0.50, 0.85, 1.4, 1.95, 2.25, 4.55]],
	["参考画像・土砂爆発", "soil", 3.3, [0.03, 0.13, 0.27, 0.47, 0.8, 1.3, 2.1, 2.8]],
	["参考画像・小爆発", "mini", 3.0, [0.03, 0.13, 0.27, 0.47, 0.8, 1.3, 2.1, 2.8]],
	["ドカン着地", "slam", 3.4, [0.03, 0.1, 0.2, 0.4, 0.7, 1.1, 2.2, 2.6]],
	["火柱", "pillar", 4.6, [0.3, 0.47, 0.6, 1.2, 2.2, 2.6, 2.85, 3.2]],
	["気合のオーラ", "aura", 4.6, [0.1, 0.3, 0.6, 1.5, 2.6, 3.0, 3.25, 3.6]],
	["インク着弾", "ink_splash", 3.2, [0.04, 0.12, 0.25, 0.5, 0.9, 1.5, 2.0, 2.4]],
	["インクボム", "ink_bomb", 4.4, [0.2, 0.6, 0.7, 0.85, 1.1, 1.6, 2.6, 3.3]],
	["インクの竜巻", "ink_tornado", 5.0, [0.2, 0.5, 1.0, 1.8, 2.5, 2.8, 3.2, 4.0]],
	["黒閃（0.4倍速）", "black_flash", 5.5, [0.0, 0.17, 0.35, 0.68, 1.18, 1.68, 2.0, 3.0]],
	["蒼", "jjk_blue", 4.0, [0.15, 0.4, 1.0, 1.8, 2.4, 2.47, 2.55, 2.9]],
	["茈", "jjk_purple", 4.2, [0.3, 0.7, 0.95, 1.0, 1.3, 1.67, 1.87, 2.6]],
	["竜巻（重ねた層）", "tornado", 5.2, [0.15, 0.4, 1.0, 2.0, 3.2, 3.5, 3.8, 4.2]],
	["炎の竜巻（巻き上がる薄い層）", "fire_tornado", 5.2, [0.15, 0.5, 0.9, 1.5, 2.4, 3.0, 3.7, 4.55]],
	["極光の返し（走る・返す・間・開く）", "aurora_refrain", 6.2, [0.35, 0.8, 1.0, 1.4, 1.95, 2.5, 3.2, 5.1]],
	["パック S：step", "pk_step", 1.2, [0.02, 0.08, 0.17, 0.27, 0.36, 0.46, 0.56, 0.63]],
	["パック S：skid", "pk_skid", 1.45, [0.03, 0.11, 0.23, 0.36, 0.49, 0.63, 0.76, 0.85]],
	["パック S：slash", "pk_slash", 1.2, [0.02, 0.08, 0.17, 0.27, 0.36, 0.46, 0.56, 0.63]],
	["パック S：claw", "pk_claw", 1.3, [0.02, 0.1, 0.19, 0.3, 0.42, 0.53, 0.64, 0.72]],
	["パック S：spike_pop", "pk_spike_pop", 2.0, [0.04, 0.18, 0.36, 0.57, 0.78, 0.99, 1.2, 1.35]],
	["パック S：chips", "pk_chips", 1.9, [0.04, 0.17, 0.34, 0.53, 0.73, 0.92, 1.12, 1.26]],
	["パック S：cross", "pk_cross", 1.25, [0.02, 0.09, 0.18, 0.29, 0.39, 0.49, 0.6, 0.68]],
	["パック S：crown", "pk_crown", 1.55, [0.03, 0.13, 0.25, 0.4, 0.55, 0.69, 0.84, 0.95]],
	["パック S：warn", "pk_warn", 1.55, [0.03, 0.13, 0.25, 0.4, 0.55, 0.69, 0.84, 0.95]],
	["パック S：drip", "pk_drip", 1.9, [0.04, 0.17, 0.34, 0.53, 0.73, 0.92, 1.12, 1.26]],
	["パック M：dash", "pk_dash", 1.8, [0.04, 0.16, 0.31, 0.49, 0.68, 0.86, 1.04, 1.17]],
	["パック M：land", "pk_land", 2.0, [0.04, 0.18, 0.36, 0.57, 0.78, 0.99, 1.2, 1.35]],
	["パック M：run_trail", "pk_run_trail", 2.9, [0.07, 0.29, 0.58, 0.91, 1.25, 1.58, 1.92, 2.16]],
	["パック M：slash3", "pk_slash3", 2.2, [0.05, 0.2, 0.41, 0.65, 0.88, 1.12, 1.36, 1.53]],
	["パック M：bite", "pk_bite", 2.1, [0.05, 0.19, 0.38, 0.61, 0.83, 1.06, 1.28, 1.44]],
	["パック M：hit", "pk_hit", 1.7, [0.04, 0.14, 0.29, 0.46, 0.62, 0.79, 0.96, 1.08]],
	["パック M：bolt3d", "pk_bolt3d", 2.4, [0.06, 0.23, 0.46, 0.72, 0.99, 1.25, 1.52, 1.71]],
	["パック M：dart", "pk_dart", 2.2, [0.05, 0.2, 0.41, 0.65, 0.88, 1.12, 1.36, 1.53]],
	["パック M：tone_burst", "pk_tone_burst", 1.7, [0.04, 0.14, 0.29, 0.46, 0.62, 0.79, 0.96, 1.08]],
	["パック M：spike_ring", "pk_spike_ring", 2.9, [0.07, 0.29, 0.58, 0.91, 1.25, 1.58, 1.92, 2.16]],
	["パック M：rag3d", "pk_rag3d", 2.1, [0.05, 0.19, 0.38, 0.61, 0.83, 1.06, 1.28, 1.44]],
	["パック M：smoke", "pk_smoke", 3.9, [0.1, 0.41, 0.82, 1.29, 1.77, 2.24, 2.72, 3.06]],
	["パック L：tornado", "pk_tornado", 5.0, [0.14, 0.54, 1.08, 1.71, 2.34, 2.97, 3.6, 4.05]],
	["パック L：arrive", "pk_arrive", 3.7, [0.1, 0.38, 0.77, 1.22, 1.66, 2.11, 2.56, 2.88]],
	["パック L：portal", "pk_portal", 5.5, [0.15, 0.6, 1.2, 1.9, 2.6, 3.3, 4.0, 4.5]],
	["パック L：chain_bind", "pk_chain_bind", 4.3, [0.11, 0.46, 0.91, 1.44, 1.98, 2.51, 3.04, 3.42]],
	["パック L：cage", "pk_cage", 4.7, [0.13, 0.5, 1.01, 1.6, 2.18, 2.77, 3.36, 3.78]],
	["パック L：storm", "pk_storm", 4.5, [0.12, 0.48, 0.96, 1.52, 2.08, 2.64, 3.2, 3.6]],
	["パック L：tower", "pk_tower", 5.1, [0.14, 0.55, 1.1, 1.75, 2.39, 3.04, 3.68, 4.14]],
	["パック L：spike_run", "pk_spike_run", 4.6, [0.12, 0.49, 0.98, 1.56, 2.13, 2.71, 3.28, 3.69]],
	["パック XL：NO ESCAPE｜22秒・装飾30系統", "pk_no_escape", 23.0, [1.5, 4.5, 7.5, 10.5, 12.6, 14.2, 17.5, 20.3]],
	["折り紙 S：step（一歩）", "og_step", 2.15, [0.04, 0.14, 0.29, 0.46, 0.65, 0.87, 1.09, 1.3]],
	["折り紙 S：hit（当たり）", "og_hit", 2.3, [0.05, 0.16, 0.32, 0.51, 0.72, 0.96, 1.2, 1.44]],
	["折り紙 S：slash（斬撃）", "og_slash", 1.9, [0.04, 0.12, 0.24, 0.38, 0.54, 0.72, 0.9, 1.08]],
	["折り紙 S：pickup（拾った）", "og_pickup", 2.4, [0.05, 0.17, 0.34, 0.54, 0.77, 1.02, 1.27, 1.53]],
	["折り紙 M：dash（急発進）", "og_dash", 2.7, [0.06, 0.2, 0.4, 0.64, 0.9, 1.2, 1.5, 1.8]],
	["折り紙 M：land（着地）", "og_land", 2.8, [0.06, 0.21, 0.42, 0.67, 0.95, 1.26, 1.58, 1.89]],
	["折り紙 M：shot（飛び道具）", "og_shot", 2.62, [0.06, 0.19, 0.38, 0.61, 0.86, 1.15, 1.44, 1.73]],
	["折り紙 M：bolt（落雷）", "og_bolt", 3.0, [0.07, 0.23, 0.46, 0.74, 1.03, 1.38, 1.72, 2.07]],
	["折り紙 M：burst（爆発）", "og_burst", 4.2, [0.1, 0.35, 0.7, 1.12, 1.57, 2.1, 2.62, 3.15]],
	["折り紙 M：heal（回復）", "og_heal", 3.3, [0.08, 0.26, 0.52, 0.83, 1.17, 1.56, 1.95, 2.34]],
	["折り紙 M：guard（防御）", "og_guard", 3.17, [0.07, 0.25, 0.49, 0.79, 1.11, 1.48, 1.85, 2.22]],
	["折り紙 M：smoke（煙）", "og_smoke", 4.5, [0.11, 0.38, 0.76, 1.22, 1.71, 2.28, 2.85, 3.42]],
	["折り紙 M：fire（炎）", "og_fire", 5.7, [0.15, 0.5, 1.0, 1.6, 2.25, 3.0, 3.75, 4.5]],
	["折り紙 L：portal（ポータル）", "og_portal", 6.7, [0.18, 0.6, 1.2, 1.92, 2.7, 3.6, 4.5, 5.4]],
	["折り紙 L：arrive（登場）", "og_arrive", 5.3, [0.14, 0.46, 0.92, 1.47, 2.07, 2.76, 3.45, 4.14]],
	["折り紙 L：tornado（竜巻）", "og_tornado", 6.5, [0.17, 0.58, 1.16, 1.86, 2.61, 3.48, 4.35, 5.22]],
	["折り紙 M：fubuki（花吹雪）", "og_fubuki", 7.85, [0.21, 0.72, 1.43, 2.29, 3.22, 4.29, 5.36, 6.44]],
	["折り紙 M：shuriken（手裏剣）", "og_shuriken", 3.13, [0.07, 0.24, 0.49, 0.78, 1.09, 1.46, 1.82, 2.19]],
	["折り紙 M：ofuda（封印）", "og_ofuda", 4.03, [0.1, 0.33, 0.67, 1.07, 1.5, 2.0, 2.5, 3.0]],
	["折り紙 M：vanish（ドロン）", "og_vanish", 4.15, [0.1, 0.35, 0.69, 1.1, 1.55, 2.07, 2.59, 3.11]],
	["折り紙 L：hanabi（花火）", "og_hanabi", 5.1, [0.13, 0.44, 0.88, 1.41, 1.98, 2.64, 3.3, 3.96]],
	["和 S：ensou（円相）", "og_ensou", 2.65, [0.06, 0.19, 0.38, 0.61, 0.86, 1.16, 1.44, 1.72]],
	["和 S：shibuki（墨しぶき）", "og_shibuki", 2.85, [0.06, 0.21, 0.41, 0.67, 0.94, 1.26, 1.58, 1.89]],
	["和 S：hanko（朱印）", "og_hanko", 2.65, [0.06, 0.19, 0.38, 0.61, 0.86, 1.16, 1.44, 1.72]],
	["和 S：suzu（鈴）", "og_suzu", 2.65, [0.06, 0.19, 0.38, 0.61, 0.86, 1.16, 1.44, 1.72]],
	["和 S：hyoshigi（拍子木）", "og_hyoshigi", 2.15, [0.04, 0.14, 0.29, 0.46, 0.66, 0.88, 1.1, 1.31]],
	["和 S：koma（独楽）", "og_koma", 2.95, [0.06, 0.22, 0.43, 0.7, 0.98, 1.32, 1.64, 1.97]],
	["和 S：daruma（だるま）", "og_daruma", 2.65, [0.06, 0.19, 0.38, 0.61, 0.86, 1.16, 1.44, 1.72]],
	["和 S：kendama（けん玉）", "og_kendama", 2.55, [0.05, 0.18, 0.36, 0.58, 0.82, 1.1, 1.37, 1.64]],
	["和 S：koban（小判）", "og_koban", 2.55, [0.05, 0.18, 0.36, 0.58, 0.82, 1.1, 1.37, 1.64]],
	["和 S：mato（的中）", "og_mato", 2.75, [0.06, 0.2, 0.4, 0.64, 0.9, 1.21, 1.51, 1.8]],
	["和 M：sho（書）", "og_sho", 3.25, [0.07, 0.24, 0.49, 0.78, 1.11, 1.49, 1.85, 2.21]],
	["和 M：koi（鯉の滝登り）", "og_koi", 3.35, [0.08, 0.25, 0.5, 0.81, 1.15, 1.54, 1.92, 2.3]],
	["和 M：kitsunebi（狐火）", "og_kitsunebi", 4.25, [0.1, 0.33, 0.67, 1.07, 1.52, 2.04, 2.53, 3.03]],
	["和 M：taiko（太鼓）", "og_taiko", 3.25, [0.07, 0.24, 0.49, 0.78, 1.11, 1.49, 1.85, 2.21]],
	["和 M：iai（居合）", "og_iai", 3.65, [0.08, 0.28, 0.56, 0.9, 1.27, 1.71, 2.12, 2.54]],
	["和 M：kingyo（金魚）", "og_kingyo", 3.65, [0.08, 0.28, 0.56, 0.9, 1.27, 1.71, 2.12, 2.54]],
	["和 M：hamaya（破魔矢）", "og_hamaya", 3.45, [0.08, 0.26, 0.52, 0.84, 1.19, 1.59, 1.99, 2.38]],
	["和 M：maneki（招き猫）", "og_maneki", 3.55, [0.08, 0.27, 0.54, 0.87, 1.23, 1.65, 2.06, 2.46]],
	["和 M：karesansui（枯山水）", "og_karesansui", 4.45, [0.11, 0.35, 0.7, 1.13, 1.6, 2.15, 2.67, 3.2]],
	["和 M：oni（鬼は外）", "og_oni", 3.95, [0.09, 0.31, 0.61, 0.99, 1.39, 1.87, 2.33, 2.79]],
	["和 L：bokuryu（墨龍）", "og_bokuryu", 5.15, [0.12, 0.41, 0.83, 1.33, 1.89, 2.53, 3.15, 3.77]],
	["和 L：sumizakura（墨桜）", "og_sumizakura", 5.85, [0.14, 0.48, 0.95, 1.54, 2.17, 2.92, 3.63, 4.35]],
	["和 L：nami（大波）", "og_nami", 4.55, [0.11, 0.36, 0.72, 1.16, 1.64, 2.2, 2.74, 3.28]],
	["和 L：koinobori（鯉のぼり）", "og_koinobori", 6.05, [0.15, 0.49, 0.99, 1.59, 2.25, 3.03, 3.77, 4.51]],
	["和 L：raijin（雷神の太鼓）", "og_raijin", 5.05, [0.12, 0.4, 0.81, 1.3, 1.84, 2.48, 3.08, 3.69]],
	["和 L：kagamibiraki（鏡開き）", "og_kagamibiraki", 4.15, [0.1, 0.32, 0.65, 1.04, 1.48, 1.98, 2.47, 2.95]],
	["和 L：shiro（城）", "og_shiro", 4.85, [0.12, 0.39, 0.77, 1.25, 1.76, 2.37, 2.95, 3.53]],
	["和 L：chikurin（竹林斬り）", "og_chikurin", 4.95, [0.12, 0.4, 0.79, 1.28, 1.8, 2.42, 3.01, 3.61]],
	["和 L：tsukimi（月見）", "og_tsukimi", 6.45, [0.16, 0.53, 1.06, 1.71, 2.42, 3.25, 4.04, 4.84]],
	["和 L：maku（幕開き）", "og_maku", 5.85, [0.14, 0.48, 0.95, 1.54, 2.17, 2.92, 3.63, 4.35]],
	["折り紙 XL：折神降ろし｜23秒・装飾30系統", "og_descent", 24.5, [1.5, 4.5, 7.5, 10.5, 13.4, 15.5, 18.5, 21.0]],
	["パンク 大：棘の地走り（3D・トーン）", "punk_spikes3d", 4.6, [0.3, 0.8, 1.3, 1.7, 2.2, 2.8, 3.2, 3.6]],
	["パンク 小：×のヒット", "punk_cross", 1.2, [0.0, 0.08, 0.17, 0.25, 0.33, 0.42, 0.5, 0.62]],
	["パンク 小：ギザギザ", "punk_zig", 1.1, [0.0, 0.08, 0.17, 0.25, 0.33, 0.42, 0.5, 0.58]],
	["パンク 小：王冠の落書き", "punk_crown", 1.5, [0.0, 0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 0.95]],
	["パンク 中：赤い布の斬撃", "punk_rag", 2.0, [0.05, 0.12, 0.2, 0.35, 0.55, 0.8, 1.05, 1.35]],
	["パンク 中：薄紫の稲妻", "punk_bolt", 1.8, [0.0, 0.08, 0.17, 0.25, 0.4, 0.6, 0.8, 1.05]],
	["パンク 大：棘の地走り", "punk_spikes", 4.0, [0.2, 0.6, 1.0, 1.5, 2.0, 2.5, 2.9, 3.2]],
	["パンクなペン画：棘の衝撃（試作）", "punk_hit", 2.2, [0.0, 0.09, 0.17, 0.3, 0.5, 0.8, 1.05, 1.3]],
	["墨の龍（地の穴から湧き、螺旋に巻き、空へ抜ける）", "ink_dragon", 5.5, [0.3, 0.8, 1.3, 1.8, 2.4, 3.0, 3.6, 4.4]],
	["墨連拳（立体の拳・墨のほぐれ）", "ink_barrage", 6.2, [0.45, 0.79, 1.23, 1.62, 2.63, 3.35, 4.15, 5.30]],
	["墨の寄せ波", "ink_undertow", 6.2, [0.25, 0.65, 1.15, 1.75, 2.45, 3.1, 4, 5.3]],
	["墨の交差流", "ink_cross", 6.2, [0.3, 0.7, 1.15, 1.55, 2.1, 2.6, 3.3, 4.9]],
	["墨の開花", "ink_bloom", 6.2, [0.22, 0.55, 1, 1.55, 2.1, 3.05, 4.05, 5.2]],
	["低音の三打", "sound_bass", 6.2, [0.25, 0.65, 1.15, 1.75, 2.35, 3, 4.35, 5.1]],
	["音の反響", "sound_echo", 6.2, [0.35, 0.6, 1, 1.35, 1.7, 2.1, 2.9, 4.6]],
	["高音共鳴", "sound_chime", 6.2, [0.5, 0.83, 1.4, 1.7, 2.25, 3.15, 4.3, 5.1]],
	["質感の型：鞭（三本が根元から振れる）", "ff_whip", 3.0, [0.1, 0.3, 0.6, 1.0, 1.5, 2.0, 2.6, 3.1]],
	["質感の型：霊気の球（八本の糸が回る）", "ff_orb", 3.0, [0.1, 0.3, 0.6, 1.0, 1.5, 2.0, 2.5, 2.8]],
	["質感の型：輪（地面の輪がたわみ流れる）", "ff_ring", 3.5, [0.2, 0.5, 0.9, 1.3, 1.8, 2.3, 2.8, 3.2]],
	["質感の型：噴流（ねじれて上へ抜ける）", "ff_jet", 3.5, [0.1, 0.4, 0.8, 1.2, 1.7, 2.2, 2.8, 3.2]],
	["質感の型：星（八本の帯が放射）", "ff_star", 3.0, [0.05, 0.2, 0.4, 0.6, 0.9, 1.3, 1.8, 2.4]],
	["黒雷：本体（黒閃の放射・六本）", "bl_burst", 3.0, [0.05, 0.15, 0.3, 0.5, 0.8, 1.2, 1.6, 2.2]],
	["黒雷：渦（竜巻に巻きつく稲妻）", "bl_vortex", 4.5, [0.3, 0.7, 1.1, 1.6, 2.1, 2.6, 3.0, 3.4]],
	["黒雷：地を這う（亀裂が赤黒く残る）", "bl_ground", 3.8, [0.2, 0.5, 0.9, 1.3, 1.7, 2.1, 2.5, 2.9]],
	["黒雷：赤黒い炎（稲妻の代わりに炎の舌）", "bl_flame", 4.2, [0.2, 0.6, 1.0, 1.4, 1.8, 2.2, 2.6, 3.1]],
	["黒雷：一閃（細い三本）", "bl_flash", 2.0, [0.02, 0.06, 0.1, 0.2, 0.35, 0.5, 0.8, 1.1]],
	["例1：水玉の魔法陣（陣が開く→泡が一粒ずつ→玉→はじける）", "water_orb", 7.6, [0.5, 1.4, 2.4, 3.0, 3.6, 4.3, 4.8, 5.6]],
	["水の斬撃（水の呼吸風：糸が集まり、三度の振り）", "water_slash", 5.4, [0.3, 0.8, 1.1, 1.6, 2.0, 2.6, 3.2, 4.2]],
	["冷気の水（霜→冷気の柱が立つ→渦→傘→霧になって降りる）", "water_ice", 6.0, [0.4, 0.9, 1.6, 2.4, 3.0, 3.6, 4.2, 4.9]],
	["漫画の水しぶき（落下→水の舌が立ち上がり倒れて戻る・集中線）", "water_manga", 5.0, [0.3, 0.7, 0.9, 1.1, 1.4, 1.8, 2.4, 3.2]],
	["大波（北斎風：立ち上がり→巻く→引く）", "water_wave", 5.6, [0.5, 1.2, 1.8, 2.4, 3.0, 3.5, 4.0, 4.8]],
	["水柱（水の竜：薄い殻の柱・螺旋のしぶき・放物線の水滴）", "water", 5.0, [0.2, 0.5, 1.0, 1.8, 2.5, 2.9, 3.3, 3.9]],
	["黒い稲妻（層の筒を折れ線に並べた試作）", "black_bolt", 2.4, [0.0, 0.07, 0.14, 0.27, 0.47, 0.67, 0.8, 1.0]],
	["Pixel×Real：炎", "px_flame", 5.0, [0.1, 0.4, 1.2, 2.0, 2.7, 3.0, 3.4, 3.9]],
	["Pixel×Real：ボクセル爆発", "px_burst", 3.0, [0.04, 0.17, 0.33, 0.5, 0.75, 1.0, 1.4, 1.9]],
	["Pixel×Real：ポータル", "px_portal", 5.4, [0.17, 0.42, 1.0, 2.5, 3.8, 4.0, 4.3, 4.67]],
	["Pixel×Real：転送", "px_teleport", 3.6, [0.25, 0.6, 1.0, 1.4, 1.58, 1.85, 2.2, 2.6]],
	["Pixel×Real：隕石", "px_meteor", 5.2, [0.25, 0.6, 1.1, 1.65, 1.9, 2.35, 3.45, 4.3]],
	["Pixel×Real：三連放電", "px_lightning", 4.8, [0.1, 0.55, 0.95, 1.70, 2.48, 2.70, 3.25, 3.9]],
	["Pixel×Real：三連火炎波", "px_fire_wave", 5.5, [0.2, 0.55, 1, 1.5, 1.95, 2.5, 3.3, 4.6]],
	["Pixel×Real：圧縮プラズマ", "px_plasma", 5.3, [0.2, 0.6, 1.1, 1.35, 1.8, 2.25, 2.8, 4.4]],
	["Pixel×Real：段瀑", "px_waterfall", 5.5, [0.35, 0.6, 1, 1.6, 2.5, 3.1, 3.8, 4.5]],
	["Pixel×Real：巻昇", "px_vortex", 5.5, [0.2, 0.6, 1, 1.6, 2.5, 3.1, 3.8, 4.5]],
	["Pixel×Real：引力返し", "px_gravity", 5.7, [0.2, 0.6, 1.15, 1.6, 2.2, 2.8, 3.6, 4.7]],
	["Pixel×Real：氷砕き", "px_ice_break", 5.5, [0.15, 0.45, 0.8, 1.1, 1.45, 2.1, 3.25, 4.5]],
	["Pixel×Real：花弁の風", "px_petals", 5.5, [0.25, 0.6, 1, 1.45, 1.9, 2.5, 3.4, 4.5]],
	["Pixel×Real：音圧の三打", "px_sonic", 5.8, [0.45, 0.85, 1.25, 1.65, 2.3, 2.75, 3.5, 4.8]],
	["墨金の噴流（生成素材＋連続コマ）", "gen_ink", 6.5, [0.3, 0.75, 1.3, 2.1, 2.5, 3.2, 4.2, 5.4]],
	["01 朱炎の裂咆｜シルエット駆動", "gen_silhouette", 6.5, [.2,.55,1.0,1.5,2.2,3.2,4.0,4.75]],
	["02 雷の枝脈｜線画→3D曲線", "gen_curve", 6.5, [.2,.55,1.0,1.5,2.2,3.2,4.0,5.0]],
	["03 亀裂の噴射｜粒子発生マップ", "gen_emission", 6.5, [.2,.55,1.0,1.5,2.2,3.2,4.0,5.0]],
	["04 結晶の開花｜画像→3Dメッシュ", "gen_mesh", 6.5, [.2,.6,1.1,1.6,2.2,3.1,4.0,5.4]],
	["05 金白の潮｜流れ場", "gen_flow", 6.5, [.2,.6,1.1,1.6,2.2,3.1,4.0,5.4]],
	["06 朱漆の剥離｜侵食パターン", "gen_erosion", 6.5, [.2,.6,1.1,1.6,2.2,3.1,4.0,5.4]],
	["07 黒金の液流｜ノーマル・AO・材質", "gen_material", 6.8, [.15,.5,1.0,1.5,2.0,2.8,4.4,5.6]],
	["太陽・磁力線の組み替え", "motif_solar", 5.0, [0.15, 0.5, 0.9, 1.25, 1.55, 2.1, 3.1, 4.55]],
	["水圧・間欠泉", "motif_geyser", 5.0, [0.15, 0.5, 0.9, 1.25, 1.65, 2.2, 3.1, 4.55]],
	["クシクラゲ・虹の伝播", "motif_jelly", 5.0, [0.15, 0.5, 0.9, 1.3, 1.8, 2.4, 3.1, 4.55]],
	["磁性流体・移動する棘", "motif_ferro", 5.0, [0.15, 0.5, 0.9, 1.3, 1.8, 2.4, 3.1, 4.55]],
	["種さや・弾性の反動", "motif_seed", 5.0, [0.15, 0.5, 0.75, 0.95, 1.3, 1.9, 2.8, 4.55]],
	["星海の戴冠門｜22秒・装飾20系統", "px_apotheosis", 23.5, [1.5,4.0,7.0,10.0,13.0,16.0,19.0,21.8]],
]+Px50.Catalog.LAB_ITEMS

const OG_VIEW := {"og_step": [5.0, 0.5], "og_hit": [6.5, 1.1], "og_slash": [6.5, 1.2], "og_pickup": [6.5, 1.5], "og_dash": [12.0, 1.6], "og_land": [7.5, 0.6], "og_shot": [12.0, 1.4], "og_bolt": [15.0, 4.6], "og_burst": [10.0, 1.5], "og_heal": [8.0, 1.7], "og_guard": [7.5, 1.4], "og_smoke": [10.0, 2.2], "og_fire": [7.5, 1.4], "og_portal": [9.0, 1.6], "og_arrive": [10.0, 1.6], "og_tornado": [14.0, 3.0], "og_fubuki": [10.0, 2.2], "og_shuriken": [10.0, 1.3], "og_ofuda": [7.5, 1.3], "og_vanish": [7.5, 1.2], "og_hanabi": [17.0, 5.0],
	"og_ensou": [4, 1.2], "og_shibuki": [6.5, 0.8], "og_hanko": [4.5, 1.25], "og_suzu": [4, 1.2], "og_hyoshigi": [4, 1.4], "og_koma": [3.5, 0.3], "og_daruma": [3.5, 0.42], "og_kendama": [4, 1.25], "og_koban": [4.5, 0.8], "og_mato": [4.5, 0.75], "og_sho": [6.5, 1.55], "og_koi": [6.5, 1.35], "og_kitsunebi": [8, 1.45], "og_taiko": [6, 1.1], "og_iai": [6, 1.05], "og_kingyo": [6, 1.05], "og_hamaya": [7, 0.9], "og_maneki": [4.5, 0.75], "og_karesansui": [9, 0.2], "og_oni": [6.5, 1.5], "og_bokuryu": [10.5, 2.6], "og_sumizakura": [9, 1.9], "og_nami": [11, 1.6], "og_koinobori": [11.5, 3.2], "og_raijin": [12, 2.8], "og_kagamibiraki": [8, 1.3], "og_shiro": [9.5, 1.7], "og_chikurin": [11, 1.9], "og_tsukimi": [10, 2.5], "og_maku": [12.5, 2.7]}        # 折り紙の汎用の演出：[カメラの距離, 注視点の高さ]

var current := 0
var loop_enabled := true
var _since := 0.0
var _yaw := 0.5
var _pitch := 0.16
var _dist := 13.0
var _drag := false
var _camera: Camera3D
var _env: Environment
var _hud: CanvasLayer
var _picker: OptionButton
var _category_picker: OptionButton
const CATEGORIES := ["爆発・衝撃", "炎・煙", "飛び道具", "墨", "音", "水", "渦・光", "雷・呪力", "Pixel×Real", "Pixel×Real・大／多", "Pixel×Real・中／標準", "Pixel×Real・小／簡潔", "生成素材", "自然のモチーフ", "質感の試作", "赤黒パンク", "折り紙・紙工作"]
var _old_tweens: Array[Tween] = []
# 別に配る VFX パック（addons/）。フォルダが無い環境でも Lab が開くように、有る時だけ読む
var _punk_fx = _pack("res://addons/punk_ink_vfx/punk_fx.gd")
var _origami_fx = _pack("res://addons/origami_vfx/origami_fx.gd")
var _pending: SceneTreeTimer


func _ready() -> void:
	Lib.warm()
	_build_studio()
	_build_panel()
	if "--shots" in OS.get_cmdline_user_args():
		_shoot.call_deferred()
	else:
		var first := 0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--only="):
				for i in ITEMS.size():
					if ITEMS[i][1] == arg.trim_prefix("--only="):
						first = i
		play(first)


func _build_studio() -> void:
	var holder := WorldEnvironment.new()
	_env = Environment.new()
	holder.environment = _env
	add_child(holder)
	set_film_look(false)
	# 倉庫と同じ作業灯
	var work := DirectionalLight3D.new()
	work.rotation_degrees = Vector3(-58, 32, 0)
	work.light_energy = 1.2
	work.light_color = Color(1.0, 0.96, 0.9)
	work.shadow_enabled = true
	add_child(work)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, -140, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.75, 0.85, 1.0)
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.31, 0.33)
	floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-15, 16):
		grid.surface_add_vertex(Vector3(i, 0.006, -15))
		grid.surface_add_vertex(Vector3(i, 0.006, 15))
		grid.surface_add_vertex(Vector3(-15, 0.006, i))
		grid.surface_add_vertex(Vector3(15, 0.006, i))
	grid.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = grid
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.4, 0.42, 0.45)
	lines.material_override = line_mat
	add_child(lines)
	# 大きさの目安：身長1.7mの人型と、効果機くらいの箱
	var person := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	person.mesh = capsule
	person.position = Vector3(-4.5, 0.85, 0.5)
	add_child(person)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.66, 0.5, 0.36)
	crate.mesh = box
	crate.position = Vector3(0, 0.25, 0)
	add_child(crate)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_aim_camera()


# 撮影カメラと同じ露出・グローに切り替える（film_camera.gd と同じ値）
func set_film_look(on: bool) -> void:
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	if on:
		_env.background_color = Color(0.012, 0.016, 0.04)
		_env.ambient_light_color = Color(0.35, 0.45, 0.8)
		_env.ambient_light_energy = 0.5
		_env.tonemap_exposure = 0.28
		_env.tonemap_white = 3.0
		_env.glow_intensity = 0.9
		_env.glow_hdr_threshold = 2.2
		_env.glow_bloom = 0.15
	else:
		_env.background_color = Color(0.03, 0.035, 0.045)
		_env.ambient_light_color = Color(0.72, 0.78, 0.92)
		_env.ambient_light_energy = 0.48
		_env.tonemap_exposure = 1.0
		_env.tonemap_white = 6.0
		_env.glow_intensity = 0.25
		_env.glow_hdr_threshold = 1.6
		_env.glow_bloom = 0.0


func _build_panel() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28)
	panel.size = Vector2(360, 0)
	var theme := Theme.new()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "sans-serif"])
	theme.default_font = sf
	theme.default_font_size = 18
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102230")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var title := Label.new()
	title.text = "VFX LAB"
	title.add_theme_font_size_override("font_size", 30)
	col.add_child(title)
	var category_label := Label.new()
	category_label.text = "大項目"
	col.add_child(category_label)
	_category_picker = OptionButton.new()
	for category: String in CATEGORIES:
		_category_picker.add_item(category)
	if _origami_fx == null:
		_category_picker.set_item_disabled(CATEGORIES.find("折り紙・紙工作"), true)
	_category_picker.focus_mode = Control.FOCUS_NONE
	_category_picker.clip_text = true
	_category_picker.item_selected.connect(_choose_category)
	col.add_child(_category_picker)
	var item_label := Label.new()
	item_label.text = "小項目 · アニメーション"
	col.add_child(item_label)
	_picker = OptionButton.new()
	_picker.fit_to_longest_item = false
	_picker.clip_text = true
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.item_selected.connect(func(index: int) -> void: play(_picker.get_item_id(index)))
	col.add_child(_picker)
	_fill_items(CATEGORIES[0])
	var again := Button.new()
	again.text = "▶ もう一度  [Enter]"
	again.custom_minimum_size.y = 42
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func() -> void: play(current))
	col.add_child(again)
	var loop := CheckBox.new()
	loop.text = "繰り返し再生"
	loop.button_pressed = true
	loop.focus_mode = Control.FOCUS_NONE
	loop.toggled.connect(func(on: bool) -> void: loop_enabled = on)
	col.add_child(loop)
	var slow := CheckBox.new()
	slow.text = "スロー再生（0.25倍）"
	slow.focus_mode = Control.FOCUS_NONE
	slow.toggled.connect(func(on: bool) -> void: Engine.time_scale = 0.25 if on else 1.0)
	col.add_child(slow)
	var film := CheckBox.new()
	film.text = "撮影カメラの明るさで見る"
	film.focus_mode = Control.FOCUS_NONE
	film.toggled.connect(set_film_look)
	col.add_child(film)
	var help := Label.new()
	help.text = "←→ で小項目を切り替え　P で一時停止\nドラッグで回転　ホイールで拡大"
	help.add_theme_font_size_override("font_size", 14)
	col.add_child(help)


static func category_for(id: String) -> String:
	if id=="px_apotheosis":return "Pixel×Real・大／多"
	if id.begins_with("px50_"):
		return "Pixel×Real・"+{"L":"大／多","M":"中／標準","S":"小／簡潔"}[Px50.Catalog.BY_ID[id]["complexity_class"]]
	if id.begins_with("gen_"): return "生成素材"
	if id.begins_with("pk_") or id.begins_with("punk_"): return "赤黒パンク"
	if id.begins_with("og_"): return "折り紙・紙工作"
	if id.begins_with("px_"): return "Pixel×Real"
	if id.begins_with("ink_"): return "墨"
	if id.begins_with("sound_"): return "音"
	if id.begins_with("water"): return "水"
	if id.begins_with("motif_"): return "自然のモチーフ"
	if id.begins_with("ff_"): return "質感の試作"
	if id == "lightning" or id.begins_with("bl_") or id.begins_with("jjk_") or id.begins_with("black_"): return "雷・呪力"
	if id.begins_with("shot_"): return "飛び道具"
	if id in ["fire", "smoke", "smoke_flat", "pillar"]: return "炎・煙"
	if id in ["tornado", "fire_tornado", "aurora_refrain", "aura"]: return "渦・光"
	return "爆発・衝撃"

static func _pack(path: String) -> GDScript:
	return load(path) if ResourceLoader.exists(path) else null


# パックが無い環境では、その項目を出さない
func _available(id: String) -> bool:
	if id.begins_with("pk_"): return _punk_fx != null
	if id.begins_with("og_"): return _origami_fx != null
	return true


func _fill_items(category: String) -> void:
	_picker.clear()
	for i in ITEMS.size():
		if category_for(ITEMS[i][1]) == category and _available(ITEMS[i][1]):
			var label: String = ITEMS[i][0]
			label = label.trim_prefix("Pixel×Real：")
			_picker.add_item(label, i)

func _choose_category(index: int) -> void:
	_fill_items(CATEGORIES[index])
	if _picker.item_count > 0: play(_picker.get_item_id(0))

func _sync_selection(index: int) -> void:
	var category := category_for(ITEMS[index][1])
	var category_index := CATEGORIES.find(category)
	if _category_picker.selected != category_index:
		_category_picker.select(category_index)
		_fill_items(category)
	_picker.select(_picker.get_item_index(index))

func _cycle_item(direction: int) -> void:
	var selected := _picker.get_item_index(current)
	var next := posmod(selected+direction, _picker.item_count)
	play(_picker.get_item_id(next))

func play(index: int) -> void:
	current = index
	if ITEMS[index][1]=="px_apotheosis":_dist=13.5
	if ITEMS[index][1] == "pk_no_escape": _dist = 19.0
	if ITEMS[index][1] == "og_descent": _dist = 21.0
	if OG_VIEW.has(ITEMS[index][1]): _dist = float(OG_VIEW[ITEMS[index][1]][0])
	if (ITEMS[index][1] as String).begins_with("px50_"):
		_dist = float(Px50.Catalog.BY_ID[ITEMS[index][1]]["dist"])
	_aim_camera()
	_since = 0.0
	_sync_selection(index)
	if _pending:
		for c in _pending.timeout.get_connections():
			_pending.timeout.disconnect(c["callable"])
		_pending = null
	for tween in _old_tweens:
		tween.kill()
	_old_tweens.clear()
	for instance in get_tree().get_nodes_in_group("pixel_real_50"):
		instance.queue_free()
	for node in get_tree().get_nodes_in_group("vfx"):
		node.queue_free()
	var center := Vector3(0, 1.3, 0)
	if (ITEMS[index][1] as String).begins_with("pk_"):
		for old in get_tree().get_nodes_in_group("punk_ink_vfx"):
			old.queue_free()
		if _punk_fx:
			_punk_fx.spawn(self, Vector3.ZERO, (ITEMS[index][1] as String).trim_prefix("pk_"))
		return
	if (ITEMS[index][1] as String).begins_with("og_"):
		var og_kind := (ITEMS[index][1] as String).trim_prefix("og_")
		if _origami_fx:
			_origami_fx.spawn(self, Vector3.ZERO, og_kind, 1.0, "matsuri", 1.0, _origami_fx.DEMO_FACING.get(og_kind, Vector3.BACK)).add_to_group("vfx")
		return
	match ITEMS[index][1] as String:
		"explosion":
			# 溜め（効果機の導火）→ 爆発。ゲームと同じ 0.8 秒
			Explosion.fuse(self, Vector3(0, 0.55, 0), 0.8)
			_pending = get_tree().create_timer(0.8, false)
			_pending.timeout.connect(func() -> void: Explosion.spawn(self, center, 3.2, 1.3, true))
		"explosion_small":
			Explosion.spawn(self, center, 0.9, 1.3, false)
		"old_explosion":
			_old_explosion(center)
		"fire":
			Fire.spawn(self, Vector3(0, 0.5, 0), 1.6)
		"smoke":
			Smoke.spawn(self, Vector3(0, 0.6, 0), 1.5)
		"smoke_flat":
			Smoke.spawn(self, Vector3(0, 0.6, 0), 1.5, -1.0, true)
		"shot_fire":
			Projectile.fire(self, Vector3(-4.5, 1.2, 0.5), Vector3(4.5, 1.2, 0.5), {"palette": "fire", "travel": 0.55})
		"shot_arcane":
			Projectile.fire(self, Vector3(-4.5, 1.2, 0.5), Vector3(4.5, 1.2, 0.5), {"palette": "arcane", "travel": 0.8, "buildup": 0.6, "ease": "in", "arc": Vector3(0, 2.5, -3.0)})
		"shot_venom":
			Projectile.fire(self, Vector3(-4.5, 1.2, 0.5), Vector3(4.5, 1.6, 0.5), {"palette": "venom", "travel": 0.6, "buildup": 0.0, "ease": "out", "size": 0.7, "hit": false})
		"lightning":
			Lightning.strike(self, Vector3(1.5, 0, 0))
		"brawl":
			Brawl.spawn(self, Vector3.ZERO, 1.6)
		"mushroom", "soil":
			Mushroom.spawn(self, Vector3.ZERO, 1.0, ITEMS[index][1])
		"mini":
			Mushroom.spawn(self, Vector3(0, 0.15, 0), 0.9, "mini")
		"slam":
			Slam.spawn(self, Vector3(1.5, 0, 0), 1.0)
		"pillar":
			FirePillar.spawn(self, Vector3(1.5, 0, 0), 1.0, 2.0)
		"aura":
			Aura.spawn(self, Vector3(-4.5, 0, 0.5), 1.0, 2.5)
		"ink_splash":
			Ink.spawn(self, Vector3(1.5, 0, 0), "splash", 1.0, "orange")
		"ink_bomb":
			Ink.spawn(self, Vector3(1.5, 0, 0), "bomb", 1.0, "pink")
		"ink_tornado":
			Ink.spawn(self, Vector3(1.5, 0, 0), "tornado", 1.0, "blue")
		"black_flash":
			BlackFlash.spawn(self, Vector3(1.5, 1.2, 0), 1.0, Vector3.RIGHT, fx_speed)
		"jjk_blue":
			Cursed.spawn(self, Vector3(1.5, 2.2, 0), "blue", 1.0)
		"punk_cross", "punk_zig", "punk_crown", "punk_rag", "punk_bolt":
			PunkSet.spawn(self, Vector3(0, 0.0 if ITEMS[index][1] == "punk_bolt" else 1.6, 0), 1.0, (ITEMS[index][1] as String).trim_prefix("punk_"))
		"punk_spikes3d":
			PunkSpikes3D.spawn(self, Vector3.ZERO, 1.0)
		"punk_spikes":
			PunkSet.spawn(self, Vector3.ZERO, 1.0, "spikes")
		"punk_hit":
			PunkHit.spawn(self, Vector3(0, 1.6, 0), 1.0)
		"ink_dragon":
			InkDragon.spawn(self, Vector3.ZERO, 1.0)
		"ink_barrage":
			InkBarrage.spawn(self, Vector3.ZERO, 1.0)
		"ink_undertow":
			InkUndertow.spawn(self, Vector3.ZERO, 1.0)
		"ink_cross":
			InkCross.spawn(self, Vector3.ZERO, 1.0)
		"ink_bloom":
			InkBloom.spawn(self, Vector3.ZERO, 1.0)
		"sound_bass":
			SoundBass.spawn(self, Vector3.ZERO, 1.0)
		"sound_echo":
			SoundEcho.spawn(self, Vector3.ZERO, 1.0)
		"sound_chime":
			SoundChime.spawn(self, Vector3.ZERO, 1.0)
		"aurora_refrain":
			AuroraRefrain.spawn(self, Vector3.ZERO, 1.0)
		"ff_whip":
			FlowForm.spawn(self, Vector3.ZERO, 1.0, "whip")
		"ff_orb":
			FlowForm.spawn(self, Vector3.ZERO, 1.0, "orb")
		"ff_ring":
			FlowForm.spawn(self, Vector3.ZERO, 1.0, "ring")
		"ff_jet":
			FlowForm.spawn(self, Vector3.ZERO, 1.0, "jet")
		"ff_star":
			FlowForm.spawn(self, Vector3.ZERO, 1.0, "star")
		"bl_burst":
			BlackLightning.spawn(self, Vector3.ZERO, 1.0, "burst")
		"bl_vortex":
			BlackLightning.spawn(self, Vector3.ZERO, 1.0, "vortex")
		"bl_ground":
			BlackLightning.spawn(self, Vector3.ZERO, 1.0, "ground")
		"bl_flame":
			BlackLightning.spawn(self, Vector3.ZERO, 1.0, "flame")
		"bl_flash":
			BlackLightning.spawn(self, Vector3.ZERO, 1.0, "flash")
		"water_orb":
			WaterOrb.spawn(self, Vector3.ZERO, 1.0)
		"water_slash":
			WaterSlash.spawn(self, Vector3.ZERO, 1.0)
		"water_ice":
			WaterIce.spawn(self, Vector3.ZERO, 1.0)
		"water_manga":
			WaterManga.spawn(self, Vector3.ZERO, 1.0)
		"water_wave":
			WaterWave.spawn(self, Vector3.ZERO, 1.0)
		"water":
			Water.spawn(self, Vector3(1.5, 0, 0), 1.0)
		"black_bolt":
			BlackBolt.spawn(self, Vector3(1.5, 1.2, 0), 1.0)
		"px_flame":
			PxFlame.spawn(self, Vector3(1.5, 0, 0), 1.6, 2.6)
		"px_burst":
			PxBurst.spawn(self, Vector3(1.5, 1.3, 0), 1.2, 1.3)
		"px_portal":
			PxPortal.spawn(self, Vector3(1.5, 2.0, 0), 1.2, 3.0)
		"px_teleport":
			PxTeleport.spawn(self, Vector3(1.5, 0, 0), 1.3)
		"px_meteor":
			PxMeteor.spawn(self, Vector3.ZERO, 1.0)
		"px_lightning":
			PxLightning.spawn(self, Vector3.ZERO, 1.0)
		"px_fire_wave":
			PxFireWave.spawn(self, Vector3.ZERO, 1.0)
		"px_plasma":
			PxPlasma.spawn(self, Vector3.ZERO, 1.0)
		"px_waterfall":
			PxWaterfall.spawn(self, Vector3.ZERO, 1.0)
		"px_vortex":
			PxVortex.spawn(self, Vector3.ZERO, 1.0)
		"px_gravity":
			PxGravity.spawn(self, Vector3.ZERO, 1.0)
		"px_ice_break":
			PxIceBreak.spawn(self, Vector3.ZERO, 1.0)
		"px_petals":
			PxPetals.spawn(self, Vector3.ZERO, 1.0)
		"px_sonic":
			PxSonic.spawn(self, Vector3.ZERO, 1.0)
		"gen_ink":
			GeneratedInk.spawn(self, Vector3.ZERO, 1.0)
		"gen_silhouette":
			GenSilhouette.spawn(self,Vector3.ZERO,1.0)
		"gen_curve":
			GenCurve.spawn(self,Vector3.ZERO,1.0)
		"gen_emission":
			GenEmission.spawn(self,Vector3.ZERO,1.0)
		"gen_mesh":
			GenMesh.spawn(self,Vector3.ZERO,1.0)
		"gen_flow":
			GenFlow.spawn(self,Vector3.ZERO,1.0)
		"gen_erosion":
			GenErosion.spawn(self,Vector3.ZERO,1.0)
		"gen_material":
			GenMaterial.spawn(self,Vector3.ZERO,1.0)
		"tornado":
			Tornado.spawn(self, Vector3(1.5, 0, 0), 1.0, 2.5, "blue")
		"fire_tornado":
			FireTornado.spawn(self, Vector3.ZERO)
		"jjk_purple":
			Cursed.spawn(self, Vector3(-5.0, 1.8, 0.5), "purple", 0.8, Vector3.RIGHT)
		"motif_solar":
			MotifSolar.spawn(self, Vector3.ZERO)
		"motif_geyser":
			MotifGeyser.spawn(self, Vector3.ZERO)
		"motif_jelly":
			MotifJelly.spawn(self, Vector3.ZERO)
		"motif_ferro":
			MotifFerro.spawn(self, Vector3.ZERO)
		"px_apotheosis":
			PxApotheosis.spawn(self,Vector3.ZERO)
		"motif_seed":
			MotifSeed.spawn(self, Vector3.ZERO)
		_:
			if ITEMS[index][1].begins_with("px50_"):
				Px50.spawn(self,Vector3.ZERO,ITEMS[index][1])


# 差し替える前の爆発（光る球 ＋ 球の粒）。見比べ用に残す。
func _old_explosion(pos: Vector3) -> void:
	var root := Node3D.new()
	root.add_to_group("vfx")
	add_child(root)
	root.global_position = pos
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.75, 0.25, 0.95)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.12)
	m.emission_energy_multiplier = 9.0
	ball.material_override = m
	root.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 60.0
	light.omni_range = 20.0
	root.add_child(light)
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.amount = 90
	parts.lifetime = 1.8
	parts.direction = Vector3.UP
	parts.spread = 75.0
	parts.initial_velocity_min = 4.0
	parts.initial_velocity_max = 11.0
	parts.gravity = Vector3(0, -6, 0)
	parts.scale_amount_min = 0.25
	parts.scale_amount_max = 0.7
	var pm := SphereMesh.new()
	pm.radius = 0.25
	pm.height = 0.5
	parts.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.5, 0.1)
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.4, 0.05)
	pmat.emission_energy_multiplier = 7.0
	parts.material_override = pmat
	root.add_child(parts)
	parts.emitting = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 7.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color", Color(0.9, 0.25, 0.05, 0.0), 1.5).set_delay(0.25)
	tw.tween_property(light, "light_energy", 0.0, 1.3)
	_old_tweens.append(tw)


func _process(delta: float) -> void:
	_since += delta
	var gap: float = ITEMS[current][2]
	if loop_enabled and gap > 0.0 and _since >= gap and _hud.visible:
		play(current)


func _aim_camera() -> void:
	var focus := Vector3(0, 4.2 if ITEMS[current][1] == "mushroom" else 2.2, 0)
	if ITEMS[current][1]=="px_apotheosis":focus.y=3.1
	if ITEMS[current][1] == "pk_no_escape": focus.y = 4.0
	if ITEMS[current][1] == "og_descent": focus.y = 4.6
	if OG_VIEW.has(ITEMS[current][1]): focus.y = float(OG_VIEW[ITEMS[current][1]][1])
	if ITEMS[current][1] == "fire_tornado": focus.y = 2.8
	if ITEMS[current][1] == "motif_ferro": focus.y = 1.1
	if (ITEMS[current][1] as String).begins_with("px50_"):
		focus.y = float(Px50.Catalog.BY_ID[ITEMS[current][1]]["focus_height"])
	_camera.position = focus + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_camera.look_at(focus)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_drag = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 40.0)
		_aim_camera()
	elif event is InputEventMouseMotion and _drag:
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.006, 0.02, 1.4)
		_aim_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER:
				play(current)
			KEY_RIGHT:
				_cycle_item(1)
			KEY_LEFT:
				_cycle_item(-1)
			KEY_P:
				get_tree().paused = not get_tree().paused


# 各エフェクトを8コマずつ撮って、1枚に並べて保存する（見た目の確認用）
func _shoot() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(false)
	_hud.visible = false
	var dir := ProjectSettings.globalize_path("res://tests/shots/vfx_review")
	DirAccess.make_dir_recursive_absolute(dir)
	var only := ""
	var custom_times: Array = []     # --times=1.0,1.1,... で撮る時刻を差し替える（動きの確認用。最大8コマ）
	var custom_dist := 0.0           # --dist=6 でカメラを寄せる（メートル）
	var tag := "flow"                # --tag=end で保存名を <id>_end.png にする（--times と一緒に使う）
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--times="):
			for part in arg.trim_prefix("--times=").split(","):
				custom_times.append(part.to_float())
		elif arg.begins_with("--speed="):
			fx_speed = arg.trim_prefix("--speed=").to_float()
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--dist="):
			custom_dist = arg.trim_prefix("--dist=").to_float()
	for film: bool in [false, true]:
		set_film_look(film)
		for index in ITEMS.size():
			var id: String = ITEMS[index][1]
			if not _available(id) or (only != "" and id != only) or (film and id not in ["explosion", "lightning", "brawl", "mushroom", "soil", "mini", "slam", "pillar", "aura", "black_flash", "jjk_blue", "jjk_purple", "tornado", "fire_tornado", "aurora_refrain", "ink_barrage", "ink_undertow", "ink_cross", "ink_bloom", "sound_bass", "sound_echo", "sound_chime", "motif_solar", "motif_geyser", "motif_jelly", "motif_ferro", "motif_seed"]):
				continue
			if film and not custom_times.is_empty():
				continue
			play(index)
			if custom_dist > 0.0:
				_dist = custom_dist
				_aim_camera()
			var times: Array = ITEMS[index][3] if custom_times.is_empty() else custom_times
			var sheet := Image.create(640 * 4, 360 * 2, false, Image.FORMAT_RGB8)
			for i in times.size():
				while _since < times[i]:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var frame := get_viewport().get_texture().get_image()
				frame.convert(Image.FORMAT_RGB8)
				frame.resize(640, 360, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(frame, Rect2i(0, 0, 640, 360), Vector2i((i % 4) * 640, (i / 4) * 360))
			sheet.save_png(dir.path_join(id + ("_film" if film else "") + ("" if custom_times.is_empty() else "_" + tag) + ".png"))
			print("VFX_SHOT ", id, " film" if film else "")
	get_tree().quit()


func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
