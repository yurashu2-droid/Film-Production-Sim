"""Label actual Godot captures separately from authored PNG face assets."""
from PIL import Image, ImageDraw, ImageChops, ImageStat
from build_assets import OUT, STATES, title
import json

def build():
    plate = Image.new("RGB", (1800, 1660), "#171c25")
    d = ImageDraw.Draw(plate)
    title(d, (40, 28), "M02 / 6つの表情", 38)
    title(d, (40, 85), "大きな画像と全身: 既存GLBに仮適用したGodot実描画  |  右下: 個別PNG原寸", 24, "#bac5d1")
    for i, (name, label, _) in enumerate(STATES):
        x = 40 + (i % 3) * 580
        y = 140 + (i // 3) * 730
        d.rounded_rectangle((x, y, x + 560, y + 700), radius=18, fill="#242c39", outline="#394351", width=2)
        title(d, (x + 20, y + 15), f"{i + 1:02}  {label}", 30)
        im = Image.open(OUT / "renders" / f"{name}_face.png").convert("RGB")
        face = im.crop((360, 100, 1240, 835)).resize((536, 448), Image.Resampling.LANCZOS)
        plate.paste(face, (x + 12, y + 73))
        body = Image.open(OUT / "renders" / f"{name}_body.png").convert("RGB")
        plate.paste(body.resize((250, 141), Image.Resampling.LANCZOS), (x + 15, y + 543))
        plate.paste(Image.open(OUT / f"{name}.png"), (x + 340, y + 551))
        title(d, (x + 340, y + 668), "128×112 px", 16, "#bac5d1")
    title(d, (40, 1620), "既存モデルと顔素材は未変更 / 検証用シーンだけに仮適用 / 通常・笑顔・驚き・困り・怒り・眠り", 21, "#bac5d1")
    plate.save(OUT / "review.png")
    angles = Image.new("RGB", (1440, 900), "#171c25")
    ad = ImageDraw.Draw(angles)
    title(ad, (20, 16), "斜めからの画面枠と表情の確認 / Godot実描画", 28)
    for i, (name, label, _) in enumerate(STATES):
        x, y = (i % 3) * 480, 72 + (i // 3) * 410
        title(ad, (x + 18, y), label, 25)
        im = Image.open(OUT / "renders" / f"{name}_diagonal.png").convert("RGB")
        angles.paste(im.crop((330, 95, 1240, 830)).resize((464, 375), Image.Resampling.LANCZOS), (x + 8, y + 34))
    angles.save(OUT / "diagonal_review.png")
    a = Image.open(OUT / "renders/source_face.png").convert("RGB")
    b = Image.open(OUT / "renders/neutral_face.png").convert("RGB")
    # The new full-cell texture must reproduce the source first-cell mapping.
    diff = ImageChops.difference(a, b)
    maximum_delta = max(hi for lo, hi in diff.getextrema())
    assert maximum_delta <= 1, "The neutral screen mapping should reproduce the source within GPU rounding."
    stats = {"source_vs_new_neutral_face_diff_bbox": diff.getbbox(),
             "neutral_render_max_rgb_delta_255": maximum_delta,
             "neutral_render_mean_rgb_delta_255": ImageStat.Stat(diff).mean,
             "neutral_render_mapping_within_one_code_value": True,
             "captures": 20, "render_size": list(a.size),
             "renderer": "Godot 4.7.2 Forward+ Vulkan; hidden dev session",
             "visual_checks": ["front face: six expressions visible within bezel", "front full-body: six expressions",
                               "diagonal face: six expressions within bezel", "native-size readability plate"],
             "integration": "preview instance only; no game expression logic edited"}
    (OUT / "review_checks.json").write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")
    print("ROBOT_EXPRESSIONS_REVIEW_OK", json.dumps(stats, ensure_ascii=False))

if __name__ == "__main__":
    build()
