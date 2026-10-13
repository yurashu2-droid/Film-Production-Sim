"""Author isolated CastM02 LED faces; never modify the source atlas or model.

Run with Python + Pillow. Pixels are designed directly at 32x28, then each
LED is expanded to 4x4 with the same gamma and grid gaps as make_m02_screens.py.
"""
from pathlib import Path
import hashlib
import json
import math
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
SOURCE = ROOT / "assets/cast/castM02_game_castM02_screen.png"
MODEL = ROOT / "assets/cast/castM02_game.glb"
W, H, PX = 32, 28, 4
LINEAR = {"background": (.004, .004, .006), "amber": (1, .55, .10)}
STATES = [("neutral", "通常", "いつもの角目"), ("happy", "笑顔", "にっこり弧の目"),
          ("surprised", "驚き", "大きな角目と開いた口"), ("worried", "困り", "下がる目尻・小さな汗"),
          ("angry", "怒り", "鋭い目と食いしばり"), ("sleep", "眠り", "閉じた目と Z")]

def gamma(v):
    return tuple(int(max(0, min(1, x)) ** (1 / 2.2) * 255) for x in v)

PALETTE = {k: gamma(v) for k, v in LINEAR.items()}

def face(name):
    im = Image.new("RGB", (W, H), PALETTE["background"])
    d = ImageDraw.Draw(im)
    a = PALETTE["amber"]
    if name == "neutral":
        d.rectangle((7, 8, 11, 12), fill=a)
        d.rectangle((20, 7, 23, 10), fill=a)
        d.rectangle((13, 17, 18, 22), outline=a)
    elif name == "happy":
        d.line([(6, 12), (9, 9), (12, 12)], fill=a)
        d.line([(20, 11), (22, 9), (24, 11)], fill=a)
        d.line([(10, 17), (11, 19), (13, 21), (18, 21), (20, 19), (21, 17)], fill=a)
    elif name == "surprised":
        d.rectangle((6, 6, 12, 12), outline=a)
        d.rectangle((20, 6, 24, 10), outline=a)
        d.rectangle((13, 17, 18, 23), outline=a)
    elif name == "worried":
        d.line([(6, 7), (8, 6), (11, 5)], fill=a)
        d.line([(20, 5), (22, 6), (24, 7)], fill=a)
        d.rectangle((7, 10, 11, 13), fill=a)
        d.rectangle((20, 9, 23, 12), fill=a)
        d.line([(12, 22), (14, 20), (17, 20), (19, 22)], fill=a)
        d.line([(27, 12), (26, 14), (26, 15), (28, 15), (28, 14), (27, 12)], fill=a)
    elif name == "angry":
        d.polygon([(6, 7), (12, 10), (12, 13), (7, 13)], fill=a)
        d.polygon([(20, 10), (24, 7), (24, 12), (20, 12)], fill=a)
        d.rectangle((11, 18, 20, 22), outline=a)
        d.line((14, 19, 14, 21), fill=a)
        d.line((17, 19, 17, 21), fill=a)
    elif name == "sleep":
        d.line((7, 11, 11, 11), fill=a)
        d.line((20, 10, 23, 10), fill=a)
        d.line((14, 20, 17, 20), fill=a)
        for y, row in enumerate(["###", "..#", ".#.", "#..", "###"]):
            for x, ch in enumerate(row):
                if ch == "#":
                    d.point((25 + x, 4 + y), fill=a)
    else:
        raise ValueError(name)
    return im

def led(native):
    # Preserve exact original conversion: dark seam is .55 of linear RGB,
    # including corners where horizontal and vertical gaps meet (not .55^2).
    src = native.load()
    im = Image.new("RGB", (W * PX, H * PX))
    dst = im.load()
    for y in range(H * PX):
        for x in range(W * PX):
            rgb = src[x // PX, y // PX]
            key = "amber" if rgb == PALETTE["amber"] else "background"
            gain = .55 if x % PX == PX - 1 or y % PX == PX - 1 else 1
            dst[x, y] = gamma(tuple(v * gain for v in LINEAR[key]))
    return im

def font(size):
    candidates = [ROOT / "assets/fonts/NotoSansJP-Regular.ttf", Path("C:/Windows/Fonts/meiryo.ttc")]
    for p in candidates:
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default(size=size)

def title(d, pos, text, size=25, color="#eef0ec"):
    d.text(pos, text, font=font(size), fill=color)

def make_comparison(images):
    plate = Image.new("RGB", (1440, 1140), "#171c25")
    d = ImageDraw.Draw(plate)
    title(d, (44, 30), "M02 / 表情の比較", 34)
    title(d, (44, 86), "既存の橙色LED・非対称の角目を保った6表情  |  2D素材の確認", 21, "#b6bfca")
    for i, (name, label, detail) in enumerate(STATES):
        x = 36 + (i % 3) * 468
        y = 148 + (i // 3) * 476
        d.rounded_rectangle((x, y, x + 444, y + 448), radius=18, fill="#242c39", outline="#394351", width=2)
        title(d, (x + 25, y + 20), f"{i + 1:02}  {label}", 28)
        title(d, (x + 25, y + 65), detail, 18, "#bdc7d2")
        plate.paste(images[name].resize((384, 336), Image.Resampling.NEAREST), (x + 30, y + 100))
    title(d, (44, 1110), "各素材 128×112 px / 論理グリッド 32×28 / 通常は既存素材と同一", 17, "#b6bfca")
    plate.save(OUT / "comparison_2d.png")

def make_small(images):
    im = Image.new("RGB", (1000, 330), "#171c25")
    d = ImageDraw.Draw(im)
    title(d, (22, 16), "小さい表示の確認  |  上: 128×112 LED  下: 32×28の論理ドット", 22)
    for i, (name, label, _) in enumerate(STATES):
        x = 22 + i * 163
        title(d, (x, 65), label, 22)
        im.paste(images[name], (x, 105))
        im.paste(face(name), (x + 48, 249))
    im.save(OUT / "readability.png")

def build():
    OUT.mkdir(exist_ok=True)
    (OUT / "native").mkdir(exist_ok=True)
    source = Image.open(SOURCE).convert("RGB")
    images = {}
    audit = []
    for name, label, detail in STATES:
        native = face(name)
        native.save(OUT / "native" / f"{name}.png")
        im = source.crop((0, 0, 128, 112)) if name == "neutral" else led(native)
        im.save(OUT / f"{name}.png")
        images[name] = im
        pixels = native.load()
        lit = [(x, y) for y in range(H) for x in range(W) if pixels[x, y] == PALETTE["amber"]]
        bounds = [min(x for x, y in lit), min(y for x, y in lit), max(x for x, y in lit), max(y for x, y in lit)]
        assert bounds[0] >= 3 and bounds[1] >= 3 and bounds[2] <= 28 and bounds[3] <= 24
        assert set(native.get_flattened_data()) == set(PALETTE.values())
        audit.append({"name": name, "label": label, "file": f"{name}.png", "lit_bounds_32x28": bounds, "lit_pixels": len(lit)})
    assert images["neutral"].tobytes() == source.crop((0, 0, 128, 112)).tobytes()
    atlas = Image.new("RGB", (128, 112 * 6))
    for row, (name, _, _) in enumerate(STATES):
        atlas.paste(images[name], (0, row * 112))
    atlas.save(OUT / "atlas_6.png")
    manifest = {"target": "CastM02", "scope": "isolated static expression proposals; no runtime integration",
                "model": str(MODEL.relative_to(ROOT)), "source": str(SOURCE.relative_to(ROOT)),
                "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                "model_sha256": hashlib.sha256(MODEL.read_bytes()).hexdigest(),
                "native_size": [W, H], "cell_size": [W * PX, H * PX], "palette_srgb": PALETTE,
                "atlas": {"image": "atlas_6.png", "cols": 1, "rows": 6, "uv_step": [1, 1/6]},
                "original_mesh_uv_bounds": [0, 0, .125, .0625],
                "single_texture_uv1_scale": [8, 16, 1],
                "atlas_texture_uv1_scale": [8, 16/6, 1],
                "filter": "original material filter (3: linear with mipmaps); clamp; mipmaps generated in preview", "states": audit,
                "neutral_exact_source_cell": True}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    make_comparison(images)
    make_small(images)
    print("ROBOT_EXPRESSIONS_ASSETS_OK", len(images), "neutral_exact=True", "safe_bounds=True")

if __name__ == "__main__":
    build()
