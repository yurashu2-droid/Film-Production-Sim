"""VFX の資料を1枚（VFX_KNOWLEDGE.md）にまとめ直す。元の資料を直したら実行する。

    python tools/build_vfx_knowledge.py

元：.claude/skills/godot-vfx/ の TASTE.md（ユーザーの好み）、PLAYBOOK.md、REVIEW-haiku.md、SKILL.md、requests/*.md
冒頭の「要点」と「動かし方」は HEAD に書いてある。ここを直せば、まとめの先頭が変わる。
"""
import io
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILL = ROOT / ".claude" / "skills" / "godot-vfx"

HEAD = """# VFX 総まとめ（Godot 4.7、コードだけで作る）

Claude Code と Codex の両方が、VFX を作る・直す時に最初に読む1枚。内容は次の資料を、そのまま順に並べたもの。
元ファイルを直したら、このファイルは作り直す（`python tools/build_vfx_knowledge.py`）。

## 最初に押さえる要点（3分で読める版）
1. **見た目の合格基準**：素材が読める／前後の層で立体感がある／形が時間で変わり流れる／終わりが汚くない。薄い殻3層は出発点で、枚数は品質点ではない。墨・煙まで白い芯にしない。
2. **消え方は主役**：作る前に「何でできていて、どう終わる物か」を1行で決める。層ごとに別の行き先・別の時刻。縮む・フェード・ノイズの穴だけ、は禁止。
3. **禁止**：円を縮めて消す（`stamp` の `hide`。`sweep` と `cut` を使う）／光線・稲妻を根元へ引き戻して消す（根元から先へ消す）／節を並べた稲妻（継ぎ目が骨に見える）／球や円柱に材質1枚。
4. **確認**：書く → 描画して画像を見る → 問題の原因を直す → 同条件で比較する。新作・大幅改修は全体・動き・実際の退出の連続コマで最低3周。文書や分類のみの修正に同じ作業を課さない。静止画で見た範囲と通常速度の動画視聴は区別して報告する。
5. **速さ**：まず通常速度で設計する。0.4倍は特定の黒閃の調整例で、全VFXの既定値にしない。予備動作・衝撃・余韻それぞれの長さを決める。
6. **ユーザーは日本語話者**。報告は日本語で、見ていない物を「確認した」と書かない。コミットは頼まれた時だけ。
7. **大・中・小は演出量**：小は主役中心、中は意味の異なる補助演出、大は複数の展開と豊富な装飾。物理サイズ・技術的な描画層数・同じ粒の個数とは別。`composition` と区分理由を記録する。

## 動かし方
```bash
GD=./tools/godot/Godot_v4.7.2-stable_win64_console.exe
$GD --path godot --fixed-fps 60 res://vfx_lab.tscn -- --shots --only=<id>                                          # 全体8コマ
$GD --path godot --fixed-fps 60 res://vfx_lab.tscn -- --shots --only=<id> --dist=10 --tag=mid --times=1.0,1.2,...  # 動き（寄り）
$GD --path godot --fixed-fps 60 res://vfx_lab.tscn -- --shots --only=<id> --dist=10 --tag=end --times=...         # 終わり（寄り）
$GD --headless --path godot --script res://tests/vfxtest.gd      # 出る・片付く
bash run_tests.sh
```
画像は `godot/tests/shots/vfx_review/` に出る。

---
"""

PARTS = [
    ("A. ユーザーの好み（却下・好評だった演出、消え方、速さ）", SKILL / "TASTE.md"),
    ("B. 手順書（作る担当が従う手順。合格基準・消え方・確認方法）", SKILL / "PLAYBOOK.md"),
    ("C. Haiku 作品のレビュー（「私ならこうする」）", SKILL / "REVIEW-haiku.md"),
    ("D. 部品・使い方・はまりどころの辞書（SKILL.md）", SKILL / "SKILL.md"),
]
PARTS += [("E. 修正依頼の見本：" + p.stem, p) for p in sorted((SKILL / "requests").glob("*.md"))]
PARTS.append(("F. Pixel×Real を売り物にするためのナレッジ", ROOT / "godot" / "pixel_vfx" / "PX_KNOWLEDGE.md"))
PARTS.append(("G. 絵柄：パンクなペン画", SKILL / "STYLE-punk-ink.md"))
PARTS.append(("H. 絵柄：折り紙・紙工作", SKILL / "STYLE-origami.md"))
PARTS.append(("I. 引き継ぎ：赤黒パンク・折り紙と VFX の資料の現状", SKILL / "HANDOVER.md"))


def body(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8").strip()
    if text.startswith("---"):                      # frontmatter を外す
        text = text.split("---", 2)[2].strip()
    return text


out = HEAD
for title, path in PARTS:
    out += f"\n\n# ===== {title} =====\n\n（元：{path.relative_to(ROOT).as_posix()}）\n\n{body(path)}\n"
(ROOT / "VFX_KNOWLEDGE.md").write_text(out, encoding="utf-8", newline="\n")
print("VFX_KNOWLEDGE.md", len(out), "文字")
