extends RefCounted
# Generated from family catalogs; update with tools/build_px50_pack.py.
const TOTAL := 53
const TIER_COUNTS := {
  "L": 1,
  "M": 16,
  "S": 36
}
const ROWS := [
  {
    "id": "px50_astral_gate",
    "name": "深星門",
    "family": "portals",
    "variant": "astral_gate",
    "size_class": "L",
    "life": 6.0,
    "gap": 6.4,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.5,
      4.7,
      5.5
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "五重の星空トンネル。逆回転の輪が奥から角度順に接続。",
    "exit": "外輪は時計回り、内輪は別の扇区から消え、闇は横走査。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "星空門の角度順接続"
      ],
      "support": [
        "星図床印の結線",
        "周縁を回る星粒"
      ],
      "decoration": []
    },
    "tier_reason": "描画の五層は主役一系統。床星図と周縁誘導の二補助を持つ。",
    "number": 1,
    "focus_height": 1.8
  },
  {
    "id": "px50_eclipse_gate",
    "name": "月蝕門",
    "family": "portals",
    "variant": "eclipse_gate",
    "size_class": "L",
    "life": 6.0,
    "gap": 6.4,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.5,
      4.7,
      5.5
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "手前の三日月と後方の完全輪。食の切り欠きが移動。",
    "exit": "三日月が横へ剥離し、上向き走査で深層が閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "月蝕の切り欠きが横断する門"
      ],
      "support": [
        "月影の床弧",
        "切り欠きに沿う周縁粒"
      ],
      "decoration": []
    },
    "tier_reason": "門一系統に移動する月影と周縁の二補助。層数は演出数に含めない。",
    "number": 2,
    "focus_height": 1.8
  },
  {
    "id": "px50_tidal_gate",
    "name": "潮汐門",
    "family": "portals",
    "variant": "tidal_gate",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.7,
      4.9,
      5.7
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "三波と七波がずれて走る潮の輪郭。縁が上下にせん断。",
    "exit": "外波が落下し、底から潮の層を払って闇を横閉じ。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "波打つ潮汐の門"
      ],
      "support": [
        "縁から落ちる滴",
        "三筋の床への流出"
      ],
      "decoration": []
    },
    "tier_reason": "波の主役に落下と床への流出という二つの補助を接続。",
    "number": 3,
    "focus_height": 1.8
  },
  {
    "id": "px50_fractured_gate",
    "name": "裂晶門",
    "family": "portals",
    "variant": "fractured_gate",
    "size_class": "L",
    "life": 6.1,
    "gap": 6.5,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.6,
      4.8,
      5.6
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "六つの扇区が別々に浮く五重の裂晶門。",
    "exit": "六分離の枠が扇区内の先端から払われ、闇は斜め走査で先に閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "六片が分離する裂晶門"
      ],
      "support": [
        "六方向の床アンカー",
        "剥離周縁の星粒"
      ],
      "decoration": []
    },
    "tier_reason": "分離する門を主役一系統とし、固定方向と周縁の二補助を持つ。",
    "number": 4,
    "focus_height": 1.8
  },
  {
    "id": "px50_summon_well",
    "name": "召喚井戸",
    "family": "portals",
    "variant": "summon_well",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.3,
      4.5,
      5.3
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "横向きに重なる五つの深い井戸層。奥から巻いて開く。",
    "exit": "井戸層ごとに異なる始点から角区画を払う。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "水平の召喚井戸"
      ],
      "support": [
        "井戸の縁を巡る少数の粒"
      ],
      "decoration": []
    },
    "tier_reason": "五層は井戸一つの奥行き。複製床印を省き、補助は縁の粒のみ。",
    "number": 5,
    "focus_height": 1.8
  },
  {
    "id": "px50_hex_door",
    "name": "六角転送",
    "family": "portals",
    "variant": "hex_door",
    "size_class": "M",
    "life": 5.7,
    "gap": 6.1,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.2,
      4.4,
      5.2
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "六角の頂点が点火し、深層が逆向きの段階回転。",
    "exit": "六辺の区画が時間差で閉じ、闇は反向きの横走査で枠より先に閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "段階回転する六角門"
      ],
      "support": [
        "六角頂点の粒アンカー",
        "床の六方向の短い括弧"
      ],
      "decoration": []
    },
    "tier_reason": "六角門の回転を、空間と床の二種類の角位置が支える。",
    "number": 6,
    "focus_height": 1.8
  },
  {
    "id": "px50_phase_window",
    "name": "位相窓",
    "family": "portals",
    "variant": "phase_window",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.3,
      4.5,
      5.3
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "矩形の窓が奥行き方向にずれ、左右走査で接続。",
    "exit": "矩形層が横へ滑り、左から右の列消去が追う。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "ずれる矩形の位相窓"
      ],
      "support": [
        "走査方向を示す二本の床レール",
        "周縁のサンプル粒"
      ],
      "decoration": []
    },
    "tier_reason": "窓一系統に走査レールと周縁サンプルの二補助。",
    "number": 7,
    "focus_height": 1.8
  },
  {
    "id": "px50_twin_gate",
    "name": "双門",
    "family": "portals",
    "variant": "twin_gate",
    "size_class": "M",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.7,
      4.9,
      5.7
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "二つの門が0.63秒差で開き、粒子の受け渡しを行う。",
    "exit": "左と右の深層が別位相で閉じ、受け渡し粒子は落ちる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "左門から右門への時差展開"
      ],
      "support": [
        "門間を渡る粒の受け渡し",
        "二つの足元接続パッド"
      ],
      "decoration": []
    },
    "tier_reason": "二門の受け渡しを一つの主展開とし、連結と足元の二補助を持つ。",
    "number": 8,
    "focus_height": 1.8
  },
  {
    "id": "px50_rune_gate",
    "name": "刻印門",
    "family": "portals",
    "variant": "rune_gate",
    "size_class": "M",
    "life": 5.9,
    "gap": 6.3,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.4,
      4.6,
      5.4
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "八つの湾曲節と刻印が相反する輪。脈打つ深層。",
    "exit": "八扇区の枠が断線し、闇は縦走査で枠より先に閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "八節の刻印門"
      ],
      "support": [
        "八文字の床刻印",
        "縁を巡る誘導粒"
      ],
      "decoration": []
    },
    "tier_reason": "刻印門一系統に床文字と周縁誘導の二補助。",
    "number": 9,
    "focus_height": 1.8
  },
  {
    "id": "px50_blink_rift",
    "name": "瞬間裂け目",
    "family": "portals",
    "variant": "blink_rift",
    "size_class": "S",
    "life": 3.5,
    "gap": 3.9,
    "full": [
      0.1,
      0.4,
      0.8,
      1.0,
      1.2,
      1.8,
      2.2,
      3.0
    ],
    "flow": [
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4
    ],
    "end": [
      2.3,
      2.4,
      2.5,
      2.6,
      2.7,
      2.8,
      2.9,
      3.0
    ],
    "dist": 5,
    "peak": 1.0,
    "description": "細い縦裂け目が短い点火で開き、側縁がずれて走る。",
    "exit": "縦走査が下から上へ進み、側層は上へ離れる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "瞬間的に走査する細い裂け目"
      ],
      "support": [
        "縁の小さな残留粒"
      ],
      "decoration": []
    },
    "tier_reason": "主役は裂け目一つ。床印を省き、補助粒を八個に限定。",
    "number": 10,
    "focus_height": 0.8
  },
  {
    "id": "px50_return_mark",
    "name": "帰還印",
    "family": "portals",
    "variant": "return_mark",
    "size_class": "S",
    "life": 4.6,
    "gap": 5.0,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      2.1,
      3.3,
      4.1
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9,
      4.0,
      4.1
    ],
    "dist": 5,
    "peak": 1.8,
    "description": "水平の菱形の帰還口。深度に重なった枠を、片側の列から閉じる。",
    "exit": "菱形の五層が左走査で断線し、闇は横から払われる。別の床印は持たない。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "床に開く菱形の帰還口"
      ],
      "support": [
        "帰還口の上を示す八個の粒"
      ],
      "decoration": []
    },
    "tier_reason": "水平の口そのものが主役。別の床輪や装飾を持たない。",
    "number": 11,
    "focus_height": 0.8
  },
  {
    "id": "px50_loot_aperture",
    "name": "宝の小門",
    "family": "portals",
    "variant": "loot_aperture",
    "size_class": "S",
    "life": 4.9,
    "gap": 5.3,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      2.4,
      3.6,
      4.4
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      3.7,
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4
    ],
    "dist": 5,
    "peak": 1.8,
    "description": "箱型の小門。矩形の明るい唇が上下から脈打つ。",
    "exit": "矩形の列走査が時間差で閉じ、奥の闇は横へ抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "屋根型に開く宝の小門"
      ],
      "support": [
        "口から立ち上る一列の粒"
      ],
      "decoration": []
    },
    "tier_reason": "小門一つと中から出る一列の粒だけの簡潔な構成。",
    "number": 12,
    "focus_height": 0.8
  },
  {
    "id": "px50_inferno_bloom",
    "name": "業火の開裂",
    "nameJP": "業火の開裂",
    "family": "action",
    "variant": "inferno_bloom",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.5,
    "dist": 9,
    "description": "二度の圧力解放で四枝の炎が編み込まれ、肩と首が遅れて割れる。",
    "exit": "供給停止後、赤い後部から浮力で昇り、橙の肩と短い白芯が別時刻に抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "二圧の裂けた噴炎"
      ],
      "support": [
        "局所の燃焼痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 13,
    "focus_height": 1.8
  },
  {
    "id": "px50_comet_crash",
    "name": "彗星衝突",
    "nameJP": "彗星衝突",
    "family": "action",
    "variant": "comet_crash",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "peak": 1.5,
    "dist": 9,
    "description": "太い斜行する熱頭が接地し、遅れた側方噴流へ圧力を渡す。",
    "exit": "熱尾は衝突点まで進み、側方炎が上昇。小石は落下し地表へ沈む。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "斜行頭と衝突後の側方噴流"
      ],
      "support": [
        "弾道の小石",
        "局所の着弾焦痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 14,
    "focus_height": 1.8
  },
  {
    "id": "px50_storm_crown",
    "name": "嵐の冠",
    "nameJP": "嵐の冠",
    "family": "action",
    "variant": "storm_crown",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ],
    "flow": [
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0,
      2.1,
      2.2
    ],
    "end": [
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7
    ],
    "peak": 2.2,
    "dist": 9,
    "description": "空中の冠から不均等な時刻で湾曲した分岐放電が地表へ下りる。",
    "exit": "冠の接続側から根元→先端へ供給が切れ、最後の枝が地面へ届く。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "冠から接地へ伝播する枝放電"
      ],
      "support": [
        "離れた接地点の短い残光"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 15,
    "focus_height": 1.8
  },
  {
    "id": "px50_frost_cataclysm",
    "name": "凍結大崩壊",
    "nameJP": "凍結大崩壊",
    "family": "action",
    "variant": "frost_cataclysm",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85,
      1.95,
      2.05
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.65,
    "dist": 9,
    "description": "低い冷気前線に結晶が育ち、固体の破断後に霧の巻き返しが上がる。",
    "exit": "結晶は回転して落下し、冷気の旧腹は上へほどける。地表の霜は区画で退く。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "地表を渡る冷気前線"
      ],
      "support": [
        "結晶の成長と落下",
        "局所の霜痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 16,
    "focus_height": 1.8
  },
  {
    "id": "px50_gravity_collapse",
    "name": "重力崩落",
    "nameJP": "重力崩落",
    "family": "action",
    "variant": "gravity_collapse",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      2.1,
      2.2,
      2.3,
      2.4,
      2.5,
      2.6,
      2.7,
      2.8
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 2.45,
    "dist": 9,
    "description": "四本の物質が渦を巻いて中心へ流入し、間を置いて四弁の反発へ転じる。",
    "exit": "流入材は中心に達して消費され、反発材は外側へ進み地面へ渡る。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "流入から反発へ転じる重力流"
      ],
      "support": [
        "地表の反発圧痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 17,
    "focus_height": 1.8
  },
  {
    "id": "px50_earth_rift",
    "name": "地裂噴圧",
    "nameJP": "地裂噴圧",
    "family": "action",
    "variant": "earth_rift",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85,
      1.95
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.7,
    "dist": 9,
    "description": "曲がった三筋の地割れから土の圧力が順番に噴き上がる。",
    "exit": "土粒は重力で戻り、噴圧の薄い後尾は上へ流出、地裂光は区画で消える。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "曲がった地裂からの噴圧"
      ],
      "support": [
        "回転落下する土片",
        "地裂に沿った圧力痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 18,
    "focus_height": 1.8
  },
  {
    "id": "px50_plasma_breaker",
    "name": "プラズマ破砕",
    "nameJP": "プラズマ破砕",
    "family": "action",
    "variant": "plasma_breaker",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "peak": 1.45,
    "dist": 9,
    "description": "二重螺旋の頭が接触し、横へ異なる長さの五枚の衝撃扇が開く。",
    "exit": "螺旋は接触点へ、衝撃扇は前方へ抜ける。青い外層が先、芯が後。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "螺旋頭から衝撃扇への受け渡し"
      ],
      "support": [
        "着弾地点の裂けた焦痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 19,
    "focus_height": 1.8
  },
  {
    "id": "px50_tidal_slam",
    "name": "大潮撃",
    "nameJP": "大潮撃",
    "family": "action",
    "variant": "tidal_slam",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0,
      2.1
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.65,
    "dist": 9,
    "description": "幅と時差のある水流の肩が弧を越えて、古い腹から落水する。",
    "exit": "水流の腹と肩が順に落下し、湿った地面の流路が区画ごとに排水。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "肩を越え腹から落下する水流"
      ],
      "support": [
        "落水後の排水流路"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 20,
    "focus_height": 1.8
  },
  {
    "id": "px50_fire_lance",
    "name": "炎槍",
    "nameJP": "炎槍",
    "family": "action",
    "variant": "fire_lance",
    "size_class": "M",
    "life": 5,
    "gap": 5.4,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      3.8,
      4.45
    ],
    "flow": [
      1.15,
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85
    ],
    "end": [
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5
    ],
    "peak": 1.5,
    "dist": 7,
    "description": "短い白熱の槍頭へ細い首と三本の熱尾が追いつく。",
    "exit": "供給は根元から切れ、頭は前進し続け、古い熱尾が昇る。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "頭を追う熱尾つきの炎槍"
      ],
      "support": [
        "着弾先の燃焼痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 21,
    "focus_height": 1.8
  },
  {
    "id": "px50_ice_shot",
    "name": "氷弾",
    "nameJP": "氷弾",
    "family": "action",
    "variant": "ice_shot",
    "size_class": "M",
    "life": 5,
    "gap": 5.4,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      3.8,
      4.45
    ],
    "flow": [
      1.15,
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85
    ],
    "end": [
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5
    ],
    "peak": 1.5,
    "dist": 7,
    "description": "冷気の移動頭が進み、着弾時に結晶の破片と遅れた冷気が分かれる。",
    "exit": "氷片は着弾先で回転し落下、後続の冷気が前へ抜け上昇。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "結晶頭と冷気の弾"
      ],
      "support": [
        "着弾時の結晶破片",
        "局所の着弾霜痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 22,
    "focus_height": 1.8
  },
  {
    "id": "px50_chain_arc",
    "name": "連鎖雷",
    "nameJP": "連鎖雷",
    "family": "action",
    "variant": "chain_arc",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.0,
      4.65
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      3.7,
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "三つの接続地点を大小の枝が時差でつなぐ。",
    "exit": "接続地点から各枝の先へ放電が消費され、後発の枝を残して先発が終了。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "三地点を受け渡す枝放電"
      ],
      "support": [
        "各接地点の残光"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 23,
    "focus_height": 1.8
  },
  {
    "id": "px50_cross_cut",
    "name": "交差斬",
    "nameJP": "交差斬",
    "family": "action",
    "variant": "cross_cut",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.0,
      4.65
    ],
    "flow": [
      1.8,
      1.9,
      2.0,
      2.1,
      2.2,
      2.3,
      2.4,
      2.5
    ],
    "end": [
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7
    ],
    "peak": 2.2,
    "dist": 7,
    "description": "異なる時刻の上昇斬・下降斬が奥行きのあるX形を作る。",
    "exit": "斬撃の後端が先端へ追いつき、二つの斬り抜けが別時刻に終わる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "時差のある交差斬撃"
      ],
      "support": [
        "斬線に沿った床の跡"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 24,
    "focus_height": 1.8
  },
  {
    "id": "px50_shield_break",
    "name": "障壁破断",
    "nameJP": "障壁破断",
    "family": "action",
    "variant": "shield_break",
    "size_class": "M",
    "life": 5.6,
    "gap": 6.0,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.4,
      5.05
    ],
    "flow": [
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5
    ],
    "end": [
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1
    ],
    "peak": 1.05,
    "dist": 7,
    "description": "凸の障壁へ走る圧力が抜け、面を構成した破片が回転して落下する。",
    "exit": "圧力が前へ逃げ、障壁片は回転落下して着地後に地表へ沈む。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "下から切れる湾曲障壁"
      ],
      "support": [
        "外へ抜ける圧力",
        "回転落下する障壁片",
        "破断点の接触痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は3系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 25,
    "focus_height": 1.8
  },
  {
    "id": "px50_sonic_punch",
    "name": "音圧拳",
    "nameJP": "音圧拳",
    "family": "action",
    "variant": "sonic_punch",
    "size_class": "M",
    "life": 5.6,
    "gap": 6.0,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.4,
      5.05
    ],
    "flow": [
      2.25,
      2.35,
      2.45,
      2.55,
      2.65,
      2.75,
      2.85,
      2.95
    ],
    "end": [
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1
    ],
    "peak": 2.7,
    "dist": 7,
    "description": "短・中・長の不等間隔三拍に、左右でずれた音圧の肩と巻き返しを持つ。",
    "exit": "各拍の古い後尾が先頭へ追いつき、第三拍はより遅く前方へ抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "短中長の三拍の音圧"
      ],
      "support": [
        "床へ届く反響圧痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 26,
    "focus_height": 1.8
  },
  {
    "id": "px50_aurora_spiral",
    "name_jp": "極光螺旋",
    "family": "elements",
    "variant": "aurora_spiral",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      5.1,
      6.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      5.3,
      5.4,
      5.5,
      5.6,
      5.7,
      5.8,
      5.9,
      6.0
    ],
    "peak": 2.7,
    "dist": 9,
    "description": "底部の磁気供給から立体の曲線束が遅れて巻き上がる",
    "exit": "供給停止後の尾が上へ進み最後の細い頭が上空へ抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "上昇して折れ返る極光の螺旋流"
      ],
      "support": [
        "磁気吸込みの地表流跡"
      ],
      "decoration": []
    },
    "tier_reason": "曲線束は一つの極光現象で、補助は底部の流跡のみ。高さや三つの材質層を数えない。",
    "name": "極光螺旋",
    "number": 27,
    "focus_height": 1.8
  },
  {
    "id": "px50_volcanic_vent",
    "name_jp": "火山噴口",
    "family": "elements",
    "variant": "volcanic_vent",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "peak": 2.7,
    "dist": 9,
    "description": "地下圧の拍が太い噴流を三方向へ分ける",
    "exit": "根元から途切れた火舌が昇り熱を失う",
    "complexity_class": "M",
    "composition": {
      "main": [
        "噴口から分岐して上昇する圧力炎"
      ],
      "support": [
        "油を含む玄武岩の地表",
        "噴口から広がる亀裂"
      ],
      "decoration": [
        "圧力抜けの短い地表スリット"
      ]
    },
    "tier_reason": "主役の圧力炎に、暗い地表・亀裂・排圧印の三役が別の時刻で加わる。",
    "name": "火山噴口",
    "number": 28,
    "focus_height": 1.8
  },
  {
    "id": "px50_sand_maelstrom",
    "name_jp": "砂塵の大渦",
    "family": "elements",
    "variant": "sand_maelstrom",
    "size_class": "L",
    "life": 6.0,
    "gap": 6.4,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.9,
      5.9
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7,
      5.8
    ],
    "peak": 2.7,
    "dist": 9,
    "description": "低い吸い込みから外へ広がる砂の巻き返し",
    "exit": "砂の流路が外へ広がり下向きに沈着する",
    "complexity_class": "S",
    "composition": {
      "main": [
        "巻上げから落砂へ移る砂塵流"
      ],
      "support": [
        "風下に堆積する砂の扇"
      ],
      "decoration": []
    },
    "tier_reason": "渦と落砂は同じ材料の主展開。独立した補助は地表の堆積だけ。",
    "name": "砂塵の大渦",
    "number": 29,
    "focus_height": 1.8
  },
  {
    "id": "px50_ember_surge",
    "name_jp": "残火の奔流",
    "family": "elements",
    "variant": "ember_surge",
    "size_class": "M",
    "life": 5,
    "gap": 5.4,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.9,
      4.9
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7,
      4.8
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "地表の残熱が水平な肩から上へ抜ける",
    "exit": "短い熱流の尾が先端へ追い付いて上へ抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "肩が上昇する残火の奔流"
      ],
      "support": [
        "通過後の熱い地表流跡"
      ],
      "decoration": []
    },
    "tier_reason": "上昇する有限の炎を主役とし、一つの熱跡だけが追う。",
    "name": "残火の奔流",
    "number": 30,
    "focus_height": 1.8
  },
  {
    "id": "px50_waterfall_fold",
    "name_jp": "折り返し滝",
    "family": "elements",
    "variant": "waterfall_fold",
    "size_class": "M",
    "life": 5.6,
    "gap": 6.0,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.5,
      5.5
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "先行する水の喉が高い唇を越えて折り返し落下",
    "exit": "水が床へ落ちて広がる波紋を扇状に拭う",
    "complexity_class": "S",
    "composition": {
      "main": [
        "持上がって折り返し落ちる水流"
      ],
      "support": [
        "接触点から進む波紋"
      ],
      "decoration": []
    },
    "tier_reason": "水流から波紋への受渡しのみ。複数の波紋面は一役として数える。",
    "name": "折り返し滝",
    "number": 31,
    "focus_height": 1.8
  },
  {
    "id": "px50_poison_breath",
    "name_jp": "毒霧吐息",
    "family": "elements",
    "variant": "poison_breath",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.1,
      5.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.3,
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "圧力の口から膨らむ三つの毒気流路",
    "exit": "外の毒気が先に上昇し内の圧力が遅れて抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "放出時差で前へ膨らむ毒の房"
      ],
      "support": [
        "低い毒の堆積跡"
      ],
      "decoration": []
    },
    "tier_reason": "主役の房と補助の地表堆積一つ。房の個数や技術層は演出量へ加算しない。",
    "name": "毒霧吐息",
    "number": 32,
    "focus_height": 1.8
  },
  {
    "id": "px50_frost_breath",
    "name_jp": "冷気吐息",
    "family": "elements",
    "variant": "frost_breath",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.1,
      5.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.3,
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "冷気の頭が低い床方向へ折れ後続を引く",
    "exit": "外の冷気が低い方へ進み床の縁光が別時刻に拭われる",
    "complexity_class": "S",
    "composition": {
      "main": [
        "低く曲がって抜ける冷気の房"
      ],
      "support": [
        "接地する霜の堆積跡"
      ],
      "decoration": []
    },
    "tier_reason": "冷気の主流と薄い霜の一役だけ。寸法が大きくても簡潔な構成。",
    "name": "冷気吐息",
    "number": 33,
    "focus_height": 1.8
  },
  {
    "id": "px50_ink_whip",
    "name_jp": "墨の鞭",
    "family": "elements",
    "variant": "ink_whip",
    "size_class": "M",
    "life": 5.4,
    "gap": 5.8,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.3,
      5.3
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "暗い墨の首が前方へ振れ枝が落下する",
    "exit": "墨が低く落ち、暗い地表染みが区画順に乾く",
    "complexity_class": "S",
    "composition": {
      "main": [
        "肩から先が鞭状に落ちる墨流"
      ],
      "support": [
        "接触先へ広がる墨の染み"
      ],
      "decoration": []
    },
    "tier_reason": "墨の主流が染みへ移る一段の受渡しで、独立した装飾はない。",
    "name": "墨の鞭",
    "number": 34,
    "focus_height": 1.8
  },
  {
    "id": "px50_holy_spring",
    "name_jp": "聖泉",
    "family": "elements",
    "variant": "holy_spring",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "地表の文字盤から三本の癒やし流路が昇る",
    "exit": "供給停止が下から伝わり上向きの材料だけが残る",
    "complexity_class": "M",
    "composition": {
      "main": [
        "上昇する癒やしの螺旋泉"
      ],
      "support": [
        "分割して回る聖泉の地表字形",
        "遅れて現れる癒やしの十字"
      ],
      "decoration": []
    },
    "tier_reason": "主泉と、分割字形・十字の二つの別役が重なる。三つの技術層は数えない。",
    "name": "聖泉",
    "number": 35,
    "focus_height": 1.8
  },
  {
    "id": "px50_ember_dash",
    "name_jp": "炎の疾走",
    "family": "elements",
    "variant": "ember_dash",
    "size_class": "M",
    "life": 4.8,
    "gap": 5.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.7,
      4.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "低い押し出しから前進する熱の肩と短い尾",
    "exit": "尾の供給が切れ熱い先端が進みながら冷える",
    "complexity_class": "S",
    "composition": {
      "main": [
        "二拍で通過する低い炎"
      ],
      "support": [
        "通過後の暖かい地表流跡"
      ],
      "decoration": []
    },
    "tier_reason": "二拍は主役のリズムであり別の装飾ではない。補助は熱跡一つ。",
    "name": "炎の疾走",
    "number": 36,
    "focus_height": 1.8
  },
  {
    "id": "px50_ether_tether",
    "name_jp": "霊気の連結",
    "family": "elements",
    "variant": "ether_tether",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "両端の供給点を分けた中央の編み込み流路",
    "exit": "二つの接続点から流れが離れて中央を通過し消える",
    "complexity_class": "S",
    "composition": {
      "main": [
        "二つの供給点を往復する霊気の連結"
      ],
      "support": [
        "両端を示す同役のアンカー印"
      ],
      "decoration": []
    },
    "tier_reason": "左右供給は一つの連結現象。左右のアンカー印も一つの補助役。",
    "name": "霊気の連結",
    "number": 37,
    "focus_height": 1.8
  },
  {
    "id": "px50_wind_cleave",
    "name_jp": "風の断層",
    "family": "elements",
    "variant": "wind_cleave",
    "size_class": "M",
    "life": 4.9,
    "gap": 5.3,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.8,
      4.8
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "二枚の肩が異なる高さで前方へ剪断する",
    "exit": "肩の供給が止まり先へ抜ける尾が最後に通過",
    "complexity_class": "S",
    "composition": {
      "main": [
        "高さの異なる肩が通過する風のせん断"
      ],
      "support": [
        "地表を横切るせん断流跡"
      ],
      "decoration": []
    },
    "tier_reason": "主役の肩と地表の一役だけ。幅や層数で格上げしない。",
    "name": "風の断層",
    "number": 38,
    "focus_height": 1.8
  },
  {
    "id": "px50_rain_contact",
    "name_jp": "雨粒の波紋",
    "family": "elements",
    "variant": "rain_contact",
    "size_class": "S",
    "life": 3.8,
    "gap": 4.2,
    "full": [
      0.1,
      0.35,
      0.65,
      0.9,
      1.3,
      2,
      2.9,
      3.7
    ],
    "flow": [
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05,
      1.15
    ],
    "end": [
      2.9,
      3.0,
      3.1,
      3.2,
      3.3,
      3.4,
      3.5,
      3.6
    ],
    "peak": 1.1,
    "dist": 5,
    "description": "三滴の接触後に遅れた波紋が外へ走る",
    "exit": "滴が床で止まり波紋が外へ進み角度順に静まる",
    "complexity_class": "S",
    "composition": {
      "main": [
        "三滴の雨が時間差で接触"
      ],
      "support": [
        "接触から外へ進む波紋"
      ],
      "decoration": []
    },
    "tier_reason": "同じ雨の反復を主役一系統、波紋を補助一系統として数える。",
    "name": "雨粒の波紋",
    "number": 39,
    "focus_height": 0.8
  },
  {
    "id": "px50_leaf_swirl",
    "name_jp": "小葉の旋風",
    "family": "elements",
    "variant": "leaf_swirl",
    "size_class": "S",
    "life": 4.2,
    "gap": 4.6,
    "full": [
      0.1,
      0.35,
      0.65,
      0.9,
      1.3,
      2,
      3.3,
      4.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      3.3,
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9,
      4.0
    ],
    "peak": 1.1,
    "dist": 5,
    "description": "低い旋回に小葉が追い付いて落ちる",
    "exit": "葉が円を離れ落下し風の尾が先へ抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "渦から放たれる小葉"
      ],
      "support": [
        "小葉を運ぶ短い風の流れ"
      ],
      "decoration": []
    },
    "tier_reason": "葉の数を独立した装飾に数えず、補助は風だけ。地表の輪は削除。",
    "name": "小葉の旋風",
    "number": 40,
    "focus_height": 0.8
  },
  {
    "id": "px50_strike_snap",
    "name": "瞬撃の火花",
    "family": "micro",
    "variant": "strike_snap",
    "size_class": "S",
    "life": 2.4,
    "gap": 2.8,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.3,
      1.6,
      2.3
    ],
    "peak": 0.42,
    "flow": [
      0.12,
      0.22,
      0.32,
      0.42,
      0.52,
      0.62,
      0.72,
      0.82
    ],
    "end": [
      0.3,
      0.4,
      0.5,
      0.6,
      0.7,
      0.8,
      0.9,
      1.0
    ],
    "dist": 5,
    "description": "五方向の短い圧力解放。先端が飛び、古い尾が遅れて追う。",
    "exit": "火流の供給を止め、後尾が前端へ追いつく。層ごとに0.038秒ずれて排出。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "放射する熱の移流"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 41,
    "focus_height": 0.8
  },
  {
    "id": "px50_ricochet_skip",
    "name": "跳弾の火流",
    "family": "micro",
    "variant": "ricochet_skip",
    "size_class": "S",
    "life": 3.1,
    "gap": 3.5,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.0,
      3.0
    ],
    "peak": 0.8,
    "flow": [
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05,
      1.15,
      1.25
    ],
    "end": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "dist": 5,
    "description": "0・0.52・0.91秒の三拍。浅くなる弧を跳ぶ熱い材料。",
    "exit": "後発の弧を残して先発から排出。弧の縮小ではなく材料が先へ抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "三拍の跳弾火流"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 42,
    "focus_height": 0.8
  },
  {
    "id": "px50_heal_sprout",
    "name": "回復の芽",
    "family": "micro",
    "variant": "heal_sprout",
    "size_class": "S",
    "life": 3.8,
    "gap": 4.2,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.7,
      3.7
    ],
    "peak": 1.1,
    "flow": [
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4
    ],
    "end": [
      2.25,
      2.35,
      2.45,
      2.55,
      2.65,
      2.75,
      2.85,
      2.95
    ],
    "dist": 5,
    "description": "不等間隔の四本の芽が、横に逃げながら巻き上がる。",
    "exit": "芽が上へ抜け、根元の五弁印を区画順に払う。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "巻き上がる回復の芽"
      ],
      "support": [
        "根元の花弁印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 43,
    "focus_height": 0.8
  },
  {
    "id": "px50_mana_tick",
    "name": "魔力の一拍",
    "family": "micro",
    "variant": "mana_tick",
    "size_class": "S",
    "life": 3.4,
    "gap": 3.8,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.3,
      3.3
    ],
    "peak": 0.8,
    "flow": [
      0.5,
      0.6,
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2
    ],
    "end": [
      2.6,
      2.7,
      2.8,
      2.9,
      3.0,
      3.1,
      3.2,
      3.3
    ],
    "dist": 5,
    "description": "三本の螺旋流が異なる位相で上へ昇る小さな回復拍。",
    "exit": "螺旋の供給停止後も先頭が上昇し、残る印を角区画で順に閉じる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "上昇する螺旋流"
      ],
      "support": [
        "応答する床印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 44,
    "focus_height": 0.8
  },
  {
    "id": "px50_frost_touch",
    "name": "霜の接触",
    "family": "micro",
    "variant": "frost_touch",
    "size_class": "S",
    "life": 3.5,
    "gap": 3.9,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.4,
      3.4
    ],
    "peak": 0.65,
    "flow": [
      0.35,
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05
    ],
    "end": [
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8
    ],
    "dist": 5,
    "description": "接触点から四方向へ冷気の丸い肩が巻き返す。",
    "exit": "旧腹が上へせん断され、冷めた後尾が細まりながら流路の先へ消費。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "四方向の冷気"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 45,
    "focus_height": 0.8
  },
  {
    "id": "px50_ember_contact",
    "name": "残火の着弾",
    "family": "micro",
    "variant": "ember_contact",
    "size_class": "S",
    "life": 3.8,
    "gap": 4.2,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.7,
      3.7
    ],
    "peak": 0.8,
    "flow": [
      0.35,
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05
    ],
    "end": [
      1.05,
      1.15,
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75
    ],
    "dist": 5,
    "description": "四つの炎舌が異なる高さへちぎれ、遅れた熱尾が追う。",
    "exit": "発生元を切り、舌が昇りながら細り、後尾の色が暗く冷める。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "離脱する炎舌"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 46,
    "focus_height": 0.8
  },
  {
    "id": "px50_poison_drop",
    "name": "毒滴の着水",
    "family": "micro",
    "variant": "poison_drop",
    "size_class": "S",
    "life": 3.7,
    "gap": 4.1000000000000005,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.6,
      3.6
    ],
    "peak": 1.05,
    "flow": [
      0.75,
      0.85,
      0.95,
      1.05,
      1.15,
      1.25,
      1.35,
      1.45
    ],
    "end": [
      1.95,
      2.05,
      2.15,
      2.25,
      2.35,
      2.45,
      2.55,
      2.65
    ],
    "dist": 5,
    "description": "落下する一滴が三回の遅れた跳ね返りと床波へ渡る。",
    "exit": "滴は着地点へ、飛沫は弧の先へ抜ける。分割波紋が外へ広がって区画順に消える。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "落下して跳ねる毒滴"
      ],
      "support": [
        "接触後の分割波紋"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 47,
    "focus_height": 0.8
  },
  {
    "id": "px50_dust_step",
    "name": "踏み出しの砂煙",
    "family": "micro",
    "variant": "dust_step",
    "size_class": "S",
    "life": 3.2,
    "gap": 3.6,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.1,
      3.1
    ],
    "peak": 0.65,
    "flow": [
      0.35,
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05
    ],
    "end": [
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8
    ],
    "dist": 5,
    "description": "踏み出しから五房の砂煙が前へずれて、複数の肩にほどける。",
    "exit": "放出を止め、茶色い房を上へ引きずりながら前へ運び出す。床を発光させない。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "上昇して希薄化する砂煙"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 48,
    "focus_height": 0.8
  },
  {
    "id": "px50_rune_ping",
    "name": "刻印の応答",
    "family": "micro",
    "variant": "rune_ping",
    "size_class": "S",
    "life": 3.6,
    "gap": 4,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.5,
      3.5
    ],
    "peak": 0.9,
    "flow": [
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4
    ],
    "end": [
      2.85,
      2.95,
      3.05,
      3.15,
      3.25,
      3.35,
      3.45,
      3.55
    ],
    "dist": 5,
    "description": "三本の刻印応答が周回し、床から少しずつ持ち上がる。",
    "exit": "周回材が先端へ排出され、三枚の印が別の始点から角度順にぬぐわれる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "周回する応答流"
      ],
      "support": [
        "床の刻印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 49,
    "focus_height": 0.8
  },
  {
    "id": "px50_charge_seed",
    "name": "蓄勢の種",
    "family": "micro",
    "variant": "charge_seed",
    "size_class": "S",
    "life": 4.1,
    "gap": 4.5,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      3.0,
      4.0
    ],
    "peak": 1.25,
    "flow": [
      0.85,
      0.95,
      1.05,
      1.15,
      1.25,
      1.35,
      1.45,
      1.55
    ],
    "end": [
      3.2,
      3.3,
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9
    ],
    "dist": 5,
    "description": "四本の内向き流が中心に集まり、間を空けて上へ一度解放する。",
    "exit": "流入は中心へ消費。解放尾は上へ抜け、床印が最後に時間差で閉じる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "中心へ集まる流入と上向きの解放"
      ],
      "support": [
        "根元の菱形印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 50,
    "focus_height": 0.8
  },
  {
    "id": "px50_constellation_loom",
    "name": "星図の織門",
    "family": "constellation_loom",
    "variant": "constellation_loom",
    "size_class": "L",
    "complexity_class": "L",
    "life": 6.4,
    "gap": 6.8,
    "full": [
      0.2,
      0.7,
      1.2,
      1.8,
      2.5,
      3.5,
      5.3,
      5.9
    ],
    "flow": [
      2.0,
      2.1,
      2.2,
      2.3,
      2.4,
      2.5,
      2.6,
      2.7
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "dist": 9,
    "peak": 3.0,
    "description": "左の供給門から中央の織門、右の受け門へ、頭と尾を持つ金色の流れが到着順に起動。離れた床星図と天冠結線、三組の周回杼が別の拍で応答する。",
    "exit": "左副門→中央→右副門の四扇区交替閉鎖。闇は反向き走査、流れは排出、天冠と床星図はそれぞれ横に消し込む。",
    "composition": {
      "main": [
        "左供給門の起動",
        "中央織門の組み上げと扇区交替",
        "右受け門の到着応答"
      ],
      "support": [
        "金色の供給・送出パケット",
        "中央門の周囲を進む三組の頭尾付き杼"
      ],
      "decoration": [
        "左右から離れた床星図の時差結線",
        "上部星図の折れた天冠結線"
      ]
    },
    "tier_reason": "幅約5.5m内に三つの主展開と、連結流・周回杼・床星図・天冠結線の四補助装飾系統が別の拍と出口を持つ。門の五層は描画技術として数えない。",
    "number": 51,
    "focus_height": 1.8
  },
  {
    "id": "px50_echo_stitch",
    "name": "反響の縫合",
    "nameJP": "反響の縫合",
    "family": "echo_stitch",
    "variant": "echo_stitch",
    "size_class": "M",
    "complexity_class": "M",
    "life": 6.3,
    "gap": 6.7,
    "dist": 9,
    "effect_size": 1.0,
    "full": [
      0.3,
      0.8,
      1.4,
      1.9,
      2.7,
      3.7,
      4.5,
      5.5
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4
    ],
    "peak": 1.4,
    "description": "左右交互に渡る反響の主弧を低い後続弧へ局所の縫い目で結び、到着側の開いた受け皿へ渡す。",
    "exit": "主弧と尾は供給元から進行先へ消費される。受け皿は外へ開き下へこぼれ、縫い目は後続弧へ解ける。最後の小紋は接続元から先へ抜ける。",
    "composition": {
      "main": [
        "三拍で左右を渡る反響主弧"
      ],
      "support": [
        "主弧を追う低い反響尾",
        "左右交互に開く受け皿"
      ],
      "decoration": [
        "主弧と尾の間の縫い目と接続点の局所小紋"
      ]
    },
    "tier_reason": "主役1系統に遅れた尾・交互の受け皿・局所の縫い目/小紋という3系統が因果と時差を持つ。幅約6mはL/S新作と比較する共通スケールであり分類理由ではない。",
    "number": 52,
    "focus_height": 1.8
  },
  {
    "id": "px50_dew_inversion",
    "name_jp": "露の反転",
    "family": "dew_inversion",
    "variant": "dew_inversion",
    "size_class": "S",
    "complexity_class": "S",
    "composition": {
      "main": [
        "接触面で巻き返るひと筋の露"
      ],
      "support": [
        "巻き返しから前へ受け渡される一枚の薄い波"
      ],
      "decoration": []
    },
    "tier_reason": "占有領域約5〜6mでも、ひと筋の露と受渡し先の一枚波だけで構成する。技術層は数えない。",
    "life": 4.8,
    "gap": 5.2,
    "full": [
      0.15,
      0.6,
      1.05,
      1.5,
      2,
      2.6,
      3.3,
      4.3
    ],
    "flow": [
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0,
      2.1,
      2.2
    ],
    "end": [
      3.3,
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9,
      4.0
    ],
    "peak": 1.8,
    "dist": 9,
    "description": "一筋の露が接触面で巻き返り一枚の薄い波へ勢いを渡す",
    "exit": "供給元から尾が進み抜け、受け取った波は前へ排水し隆起が地表へ戻る",
    "name": "露の反転",
    "number": 53,
    "focus_height": 1.8
  }
]
const BY_ID := {
  "px50_astral_gate": {
    "id": "px50_astral_gate",
    "name": "深星門",
    "family": "portals",
    "variant": "astral_gate",
    "size_class": "L",
    "life": 6.0,
    "gap": 6.4,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.5,
      4.7,
      5.5
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "五重の星空トンネル。逆回転の輪が奥から角度順に接続。",
    "exit": "外輪は時計回り、内輪は別の扇区から消え、闇は横走査。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "星空門の角度順接続"
      ],
      "support": [
        "星図床印の結線",
        "周縁を回る星粒"
      ],
      "decoration": []
    },
    "tier_reason": "描画の五層は主役一系統。床星図と周縁誘導の二補助を持つ。",
    "number": 1,
    "focus_height": 1.8
  },
  "px50_eclipse_gate": {
    "id": "px50_eclipse_gate",
    "name": "月蝕門",
    "family": "portals",
    "variant": "eclipse_gate",
    "size_class": "L",
    "life": 6.0,
    "gap": 6.4,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.5,
      4.7,
      5.5
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "手前の三日月と後方の完全輪。食の切り欠きが移動。",
    "exit": "三日月が横へ剥離し、上向き走査で深層が閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "月蝕の切り欠きが横断する門"
      ],
      "support": [
        "月影の床弧",
        "切り欠きに沿う周縁粒"
      ],
      "decoration": []
    },
    "tier_reason": "門一系統に移動する月影と周縁の二補助。層数は演出数に含めない。",
    "number": 2,
    "focus_height": 1.8
  },
  "px50_tidal_gate": {
    "id": "px50_tidal_gate",
    "name": "潮汐門",
    "family": "portals",
    "variant": "tidal_gate",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.7,
      4.9,
      5.7
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "三波と七波がずれて走る潮の輪郭。縁が上下にせん断。",
    "exit": "外波が落下し、底から潮の層を払って闇を横閉じ。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "波打つ潮汐の門"
      ],
      "support": [
        "縁から落ちる滴",
        "三筋の床への流出"
      ],
      "decoration": []
    },
    "tier_reason": "波の主役に落下と床への流出という二つの補助を接続。",
    "number": 3,
    "focus_height": 1.8
  },
  "px50_fractured_gate": {
    "id": "px50_fractured_gate",
    "name": "裂晶門",
    "family": "portals",
    "variant": "fractured_gate",
    "size_class": "L",
    "life": 6.1,
    "gap": 6.5,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.6,
      4.8,
      5.6
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "dist": 9,
    "peak": 1.8,
    "description": "六つの扇区が別々に浮く五重の裂晶門。",
    "exit": "六分離の枠が扇区内の先端から払われ、闇は斜め走査で先に閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "六片が分離する裂晶門"
      ],
      "support": [
        "六方向の床アンカー",
        "剥離周縁の星粒"
      ],
      "decoration": []
    },
    "tier_reason": "分離する門を主役一系統とし、固定方向と周縁の二補助を持つ。",
    "number": 4,
    "focus_height": 1.8
  },
  "px50_summon_well": {
    "id": "px50_summon_well",
    "name": "召喚井戸",
    "family": "portals",
    "variant": "summon_well",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.3,
      4.5,
      5.3
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "横向きに重なる五つの深い井戸層。奥から巻いて開く。",
    "exit": "井戸層ごとに異なる始点から角区画を払う。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "水平の召喚井戸"
      ],
      "support": [
        "井戸の縁を巡る少数の粒"
      ],
      "decoration": []
    },
    "tier_reason": "五層は井戸一つの奥行き。複製床印を省き、補助は縁の粒のみ。",
    "number": 5,
    "focus_height": 1.8
  },
  "px50_hex_door": {
    "id": "px50_hex_door",
    "name": "六角転送",
    "family": "portals",
    "variant": "hex_door",
    "size_class": "M",
    "life": 5.7,
    "gap": 6.1,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.2,
      4.4,
      5.2
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "六角の頂点が点火し、深層が逆向きの段階回転。",
    "exit": "六辺の区画が時間差で閉じ、闇は反向きの横走査で枠より先に閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "段階回転する六角門"
      ],
      "support": [
        "六角頂点の粒アンカー",
        "床の六方向の短い括弧"
      ],
      "decoration": []
    },
    "tier_reason": "六角門の回転を、空間と床の二種類の角位置が支える。",
    "number": 6,
    "focus_height": 1.8
  },
  "px50_phase_window": {
    "id": "px50_phase_window",
    "name": "位相窓",
    "family": "portals",
    "variant": "phase_window",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.3,
      4.5,
      5.3
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "矩形の窓が奥行き方向にずれ、左右走査で接続。",
    "exit": "矩形層が横へ滑り、左から右の列消去が追う。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "ずれる矩形の位相窓"
      ],
      "support": [
        "走査方向を示す二本の床レール",
        "周縁のサンプル粒"
      ],
      "decoration": []
    },
    "tier_reason": "窓一系統に走査レールと周縁サンプルの二補助。",
    "number": 7,
    "focus_height": 1.8
  },
  "px50_twin_gate": {
    "id": "px50_twin_gate",
    "name": "双門",
    "family": "portals",
    "variant": "twin_gate",
    "size_class": "M",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.7,
      4.9,
      5.7
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "二つの門が0.63秒差で開き、粒子の受け渡しを行う。",
    "exit": "左と右の深層が別位相で閉じ、受け渡し粒子は落ちる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "左門から右門への時差展開"
      ],
      "support": [
        "門間を渡る粒の受け渡し",
        "二つの足元接続パッド"
      ],
      "decoration": []
    },
    "tier_reason": "二門の受け渡しを一つの主展開とし、連結と足元の二補助を持つ。",
    "number": 8,
    "focus_height": 1.8
  },
  "px50_rune_gate": {
    "id": "px50_rune_gate",
    "name": "刻印門",
    "family": "portals",
    "variant": "rune_gate",
    "size_class": "M",
    "life": 5.9,
    "gap": 6.3,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.4,
      4.6,
      5.4
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4
    ],
    "dist": 7,
    "peak": 1.8,
    "description": "八つの湾曲節と刻印が相反する輪。脈打つ深層。",
    "exit": "八扇区の枠が断線し、闇は縦走査で枠より先に閉じる。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "八節の刻印門"
      ],
      "support": [
        "八文字の床刻印",
        "縁を巡る誘導粒"
      ],
      "decoration": []
    },
    "tier_reason": "刻印門一系統に床文字と周縁誘導の二補助。",
    "number": 9,
    "focus_height": 1.8
  },
  "px50_blink_rift": {
    "id": "px50_blink_rift",
    "name": "瞬間裂け目",
    "family": "portals",
    "variant": "blink_rift",
    "size_class": "S",
    "life": 3.5,
    "gap": 3.9,
    "full": [
      0.1,
      0.4,
      0.8,
      1.0,
      1.2,
      1.8,
      2.2,
      3.0
    ],
    "flow": [
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4
    ],
    "end": [
      2.3,
      2.4,
      2.5,
      2.6,
      2.7,
      2.8,
      2.9,
      3.0
    ],
    "dist": 5,
    "peak": 1.0,
    "description": "細い縦裂け目が短い点火で開き、側縁がずれて走る。",
    "exit": "縦走査が下から上へ進み、側層は上へ離れる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "瞬間的に走査する細い裂け目"
      ],
      "support": [
        "縁の小さな残留粒"
      ],
      "decoration": []
    },
    "tier_reason": "主役は裂け目一つ。床印を省き、補助粒を八個に限定。",
    "number": 10,
    "focus_height": 0.8
  },
  "px50_return_mark": {
    "id": "px50_return_mark",
    "name": "帰還印",
    "family": "portals",
    "variant": "return_mark",
    "size_class": "S",
    "life": 4.6,
    "gap": 5.0,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      2.1,
      3.3,
      4.1
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9,
      4.0,
      4.1
    ],
    "dist": 5,
    "peak": 1.8,
    "description": "水平の菱形の帰還口。深度に重なった枠を、片側の列から閉じる。",
    "exit": "菱形の五層が左走査で断線し、闇は横から払われる。別の床印は持たない。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "床に開く菱形の帰還口"
      ],
      "support": [
        "帰還口の上を示す八個の粒"
      ],
      "decoration": []
    },
    "tier_reason": "水平の口そのものが主役。別の床輪や装飾を持たない。",
    "number": 11,
    "focus_height": 0.8
  },
  "px50_loot_aperture": {
    "id": "px50_loot_aperture",
    "name": "宝の小門",
    "family": "portals",
    "variant": "loot_aperture",
    "size_class": "S",
    "life": 4.9,
    "gap": 5.3,
    "full": [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      2.4,
      3.6,
      4.4
    ],
    "flow": [
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0
    ],
    "end": [
      3.7,
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4
    ],
    "dist": 5,
    "peak": 1.8,
    "description": "箱型の小門。矩形の明るい唇が上下から脈打つ。",
    "exit": "矩形の列走査が時間差で閉じ、奥の闇は横へ抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "屋根型に開く宝の小門"
      ],
      "support": [
        "口から立ち上る一列の粒"
      ],
      "decoration": []
    },
    "tier_reason": "小門一つと中から出る一列の粒だけの簡潔な構成。",
    "number": 12,
    "focus_height": 0.8
  },
  "px50_inferno_bloom": {
    "id": "px50_inferno_bloom",
    "name": "業火の開裂",
    "nameJP": "業火の開裂",
    "family": "action",
    "variant": "inferno_bloom",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.5,
    "dist": 9,
    "description": "二度の圧力解放で四枝の炎が編み込まれ、肩と首が遅れて割れる。",
    "exit": "供給停止後、赤い後部から浮力で昇り、橙の肩と短い白芯が別時刻に抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "二圧の裂けた噴炎"
      ],
      "support": [
        "局所の燃焼痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 13,
    "focus_height": 1.8
  },
  "px50_comet_crash": {
    "id": "px50_comet_crash",
    "name": "彗星衝突",
    "nameJP": "彗星衝突",
    "family": "action",
    "variant": "comet_crash",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "peak": 1.5,
    "dist": 9,
    "description": "太い斜行する熱頭が接地し、遅れた側方噴流へ圧力を渡す。",
    "exit": "熱尾は衝突点まで進み、側方炎が上昇。小石は落下し地表へ沈む。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "斜行頭と衝突後の側方噴流"
      ],
      "support": [
        "弾道の小石",
        "局所の着弾焦痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 14,
    "focus_height": 1.8
  },
  "px50_storm_crown": {
    "id": "px50_storm_crown",
    "name": "嵐の冠",
    "nameJP": "嵐の冠",
    "family": "action",
    "variant": "storm_crown",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ],
    "flow": [
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0,
      2.1,
      2.2
    ],
    "end": [
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7
    ],
    "peak": 2.2,
    "dist": 9,
    "description": "空中の冠から不均等な時刻で湾曲した分岐放電が地表へ下りる。",
    "exit": "冠の接続側から根元→先端へ供給が切れ、最後の枝が地面へ届く。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "冠から接地へ伝播する枝放電"
      ],
      "support": [
        "離れた接地点の短い残光"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 15,
    "focus_height": 1.8
  },
  "px50_frost_cataclysm": {
    "id": "px50_frost_cataclysm",
    "name": "凍結大崩壊",
    "nameJP": "凍結大崩壊",
    "family": "action",
    "variant": "frost_cataclysm",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85,
      1.95,
      2.05
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.65,
    "dist": 9,
    "description": "低い冷気前線に結晶が育ち、固体の破断後に霧の巻き返しが上がる。",
    "exit": "結晶は回転して落下し、冷気の旧腹は上へほどける。地表の霜は区画で退く。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "地表を渡る冷気前線"
      ],
      "support": [
        "結晶の成長と落下",
        "局所の霜痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 16,
    "focus_height": 1.8
  },
  "px50_gravity_collapse": {
    "id": "px50_gravity_collapse",
    "name": "重力崩落",
    "nameJP": "重力崩落",
    "family": "action",
    "variant": "gravity_collapse",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      2.1,
      2.2,
      2.3,
      2.4,
      2.5,
      2.6,
      2.7,
      2.8
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 2.45,
    "dist": 9,
    "description": "四本の物質が渦を巻いて中心へ流入し、間を置いて四弁の反発へ転じる。",
    "exit": "流入材は中心に達して消費され、反発材は外側へ進み地面へ渡る。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "流入から反発へ転じる重力流"
      ],
      "support": [
        "地表の反発圧痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 17,
    "focus_height": 1.8
  },
  "px50_earth_rift": {
    "id": "px50_earth_rift",
    "name": "地裂噴圧",
    "nameJP": "地裂噴圧",
    "family": "action",
    "variant": "earth_rift",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85,
      1.95
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.7,
    "dist": 9,
    "description": "曲がった三筋の地割れから土の圧力が順番に噴き上がる。",
    "exit": "土粒は重力で戻り、噴圧の薄い後尾は上へ流出、地裂光は区画で消える。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "曲がった地裂からの噴圧"
      ],
      "support": [
        "回転落下する土片",
        "地裂に沿った圧力痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 18,
    "focus_height": 1.8
  },
  "px50_plasma_breaker": {
    "id": "px50_plasma_breaker",
    "name": "プラズマ破砕",
    "nameJP": "プラズマ破砕",
    "family": "action",
    "variant": "plasma_breaker",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3
    ],
    "peak": 1.45,
    "dist": 9,
    "description": "二重螺旋の頭が接触し、横へ異なる長さの五枚の衝撃扇が開く。",
    "exit": "螺旋は接触点へ、衝撃扇は前方へ抜ける。青い外層が先、芯が後。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "螺旋頭から衝撃扇への受け渡し"
      ],
      "support": [
        "着弾地点の裂けた焦痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 19,
    "focus_height": 1.8
  },
  "px50_tidal_slam": {
    "id": "px50_tidal_slam",
    "name": "大潮撃",
    "nameJP": "大潮撃",
    "family": "action",
    "variant": "tidal_slam",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ],
    "flow": [
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0,
      2.1
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "peak": 1.65,
    "dist": 9,
    "description": "幅と時差のある水流の肩が弧を越えて、古い腹から落水する。",
    "exit": "水流の腹と肩が順に落下し、湿った地面の流路が区画ごとに排水。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "肩を越え腹から落下する水流"
      ],
      "support": [
        "落水後の排水流路"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 20,
    "focus_height": 1.8
  },
  "px50_fire_lance": {
    "id": "px50_fire_lance",
    "name": "炎槍",
    "nameJP": "炎槍",
    "family": "action",
    "variant": "fire_lance",
    "size_class": "M",
    "life": 5,
    "gap": 5.4,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      3.8,
      4.45
    ],
    "flow": [
      1.15,
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85
    ],
    "end": [
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5
    ],
    "peak": 1.5,
    "dist": 7,
    "description": "短い白熱の槍頭へ細い首と三本の熱尾が追いつく。",
    "exit": "供給は根元から切れ、頭は前進し続け、古い熱尾が昇る。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "頭を追う熱尾つきの炎槍"
      ],
      "support": [
        "着弾先の燃焼痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 21,
    "focus_height": 1.8
  },
  "px50_ice_shot": {
    "id": "px50_ice_shot",
    "name": "氷弾",
    "nameJP": "氷弾",
    "family": "action",
    "variant": "ice_shot",
    "size_class": "M",
    "life": 5,
    "gap": 5.4,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      3.8,
      4.45
    ],
    "flow": [
      1.15,
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75,
      1.85
    ],
    "end": [
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5
    ],
    "peak": 1.5,
    "dist": 7,
    "description": "冷気の移動頭が進み、着弾時に結晶の破片と遅れた冷気が分かれる。",
    "exit": "氷片は着弾先で回転し落下、後続の冷気が前へ抜け上昇。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "結晶頭と冷気の弾"
      ],
      "support": [
        "着弾時の結晶破片",
        "局所の着弾霜痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は2系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 22,
    "focus_height": 1.8
  },
  "px50_chain_arc": {
    "id": "px50_chain_arc",
    "name": "連鎖雷",
    "nameJP": "連鎖雷",
    "family": "action",
    "variant": "chain_arc",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.0,
      4.65
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      3.7,
      3.8,
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "三つの接続地点を大小の枝が時差でつなぐ。",
    "exit": "接続地点から各枝の先へ放電が消費され、後発の枝を残して先発が終了。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "三地点を受け渡す枝放電"
      ],
      "support": [
        "各接地点の残光"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 23,
    "focus_height": 1.8
  },
  "px50_cross_cut": {
    "id": "px50_cross_cut",
    "name": "交差斬",
    "nameJP": "交差斬",
    "family": "action",
    "variant": "cross_cut",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.0,
      4.65
    ],
    "flow": [
      1.8,
      1.9,
      2.0,
      2.1,
      2.2,
      2.3,
      2.4,
      2.5
    ],
    "end": [
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7
    ],
    "peak": 2.2,
    "dist": 7,
    "description": "異なる時刻の上昇斬・下降斬が奥行きのあるX形を作る。",
    "exit": "斬撃の後端が先端へ追いつき、二つの斬り抜けが別時刻に終わる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "時差のある交差斬撃"
      ],
      "support": [
        "斬線に沿った床の跡"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 24,
    "focus_height": 1.8
  },
  "px50_shield_break": {
    "id": "px50_shield_break",
    "name": "障壁破断",
    "nameJP": "障壁破断",
    "family": "action",
    "variant": "shield_break",
    "size_class": "M",
    "life": 5.6,
    "gap": 6.0,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.4,
      5.05
    ],
    "flow": [
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5
    ],
    "end": [
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1
    ],
    "peak": 1.05,
    "dist": 7,
    "description": "凸の障壁へ走る圧力が抜け、面を構成した破片が回転して落下する。",
    "exit": "圧力が前へ逃げ、障壁片は回転落下して着地後に地表へ沈む。",
    "complexity_class": "M",
    "composition": {
      "main": [
        "下から切れる湾曲障壁"
      ],
      "support": [
        "外へ抜ける圧力",
        "回転落下する障壁片",
        "破断点の接触痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は3系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 25,
    "focus_height": 1.8
  },
  "px50_sonic_punch": {
    "id": "px50_sonic_punch",
    "name": "音圧拳",
    "nameJP": "音圧拳",
    "family": "action",
    "variant": "sonic_punch",
    "size_class": "M",
    "life": 5.6,
    "gap": 6.0,
    "full": [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.4,
      5.05
    ],
    "flow": [
      2.25,
      2.35,
      2.45,
      2.55,
      2.65,
      2.75,
      2.85,
      2.95
    ],
    "end": [
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1
    ],
    "peak": 2.7,
    "dist": 7,
    "description": "短・中・長の不等間隔三拍に、左右でずれた音圧の肩と巻き返しを持つ。",
    "exit": "各拍の古い後尾が先頭へ追いつき、第三拍はより遅く前方へ抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "短中長の三拍の音圧"
      ],
      "support": [
        "床へ届く反響圧痕"
      ],
      "decoration": []
    },
    "tier_reason": "主役の異なる拍・枝・3殻は同一系統として数え、補助は1系統。物理占有範囲と旧size_classでは分類しない。",
    "number": 26,
    "focus_height": 1.8
  },
  "px50_aurora_spiral": {
    "id": "px50_aurora_spiral",
    "name_jp": "極光螺旋",
    "family": "elements",
    "variant": "aurora_spiral",
    "size_class": "L",
    "life": 6.2,
    "gap": 6.6,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      5.1,
      6.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      5.3,
      5.4,
      5.5,
      5.6,
      5.7,
      5.8,
      5.9,
      6.0
    ],
    "peak": 2.7,
    "dist": 9,
    "description": "底部の磁気供給から立体の曲線束が遅れて巻き上がる",
    "exit": "供給停止後の尾が上へ進み最後の細い頭が上空へ抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "上昇して折れ返る極光の螺旋流"
      ],
      "support": [
        "磁気吸込みの地表流跡"
      ],
      "decoration": []
    },
    "tier_reason": "曲線束は一つの極光現象で、補助は底部の流跡のみ。高さや三つの材質層を数えない。",
    "name": "極光螺旋",
    "number": 27,
    "focus_height": 1.8
  },
  "px50_volcanic_vent": {
    "id": "px50_volcanic_vent",
    "name_jp": "火山噴口",
    "family": "elements",
    "variant": "volcanic_vent",
    "size_class": "L",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "peak": 2.7,
    "dist": 9,
    "description": "地下圧の拍が太い噴流を三方向へ分ける",
    "exit": "根元から途切れた火舌が昇り熱を失う",
    "complexity_class": "M",
    "composition": {
      "main": [
        "噴口から分岐して上昇する圧力炎"
      ],
      "support": [
        "油を含む玄武岩の地表",
        "噴口から広がる亀裂"
      ],
      "decoration": [
        "圧力抜けの短い地表スリット"
      ]
    },
    "tier_reason": "主役の圧力炎に、暗い地表・亀裂・排圧印の三役が別の時刻で加わる。",
    "name": "火山噴口",
    "number": 28,
    "focus_height": 1.8
  },
  "px50_sand_maelstrom": {
    "id": "px50_sand_maelstrom",
    "name_jp": "砂塵の大渦",
    "family": "elements",
    "variant": "sand_maelstrom",
    "size_class": "L",
    "life": 6.0,
    "gap": 6.4,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.9,
      5.9
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7,
      5.8
    ],
    "peak": 2.7,
    "dist": 9,
    "description": "低い吸い込みから外へ広がる砂の巻き返し",
    "exit": "砂の流路が外へ広がり下向きに沈着する",
    "complexity_class": "S",
    "composition": {
      "main": [
        "巻上げから落砂へ移る砂塵流"
      ],
      "support": [
        "風下に堆積する砂の扇"
      ],
      "decoration": []
    },
    "tier_reason": "渦と落砂は同じ材料の主展開。独立した補助は地表の堆積だけ。",
    "name": "砂塵の大渦",
    "number": 29,
    "focus_height": 1.8
  },
  "px50_ember_surge": {
    "id": "px50_ember_surge",
    "name_jp": "残火の奔流",
    "family": "elements",
    "variant": "ember_surge",
    "size_class": "M",
    "life": 5,
    "gap": 5.4,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.9,
      4.9
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7,
      4.8
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "地表の残熱が水平な肩から上へ抜ける",
    "exit": "短い熱流の尾が先端へ追い付いて上へ抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "肩が上昇する残火の奔流"
      ],
      "support": [
        "通過後の熱い地表流跡"
      ],
      "decoration": []
    },
    "tier_reason": "上昇する有限の炎を主役とし、一つの熱跡だけが追う。",
    "name": "残火の奔流",
    "number": 30,
    "focus_height": 1.8
  },
  "px50_waterfall_fold": {
    "id": "px50_waterfall_fold",
    "name_jp": "折り返し滝",
    "family": "elements",
    "variant": "waterfall_fold",
    "size_class": "M",
    "life": 5.6,
    "gap": 6.0,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.5,
      5.5
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "先行する水の喉が高い唇を越えて折り返し落下",
    "exit": "水が床へ落ちて広がる波紋を扇状に拭う",
    "complexity_class": "S",
    "composition": {
      "main": [
        "持上がって折り返し落ちる水流"
      ],
      "support": [
        "接触点から進む波紋"
      ],
      "decoration": []
    },
    "tier_reason": "水流から波紋への受渡しのみ。複数の波紋面は一役として数える。",
    "name": "折り返し滝",
    "number": 31,
    "focus_height": 1.8
  },
  "px50_poison_breath": {
    "id": "px50_poison_breath",
    "name_jp": "毒霧吐息",
    "family": "elements",
    "variant": "poison_breath",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.1,
      5.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.3,
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "圧力の口から膨らむ三つの毒気流路",
    "exit": "外の毒気が先に上昇し内の圧力が遅れて抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "放出時差で前へ膨らむ毒の房"
      ],
      "support": [
        "低い毒の堆積跡"
      ],
      "decoration": []
    },
    "tier_reason": "主役の房と補助の地表堆積一つ。房の個数や技術層は演出量へ加算しない。",
    "name": "毒霧吐息",
    "number": 32,
    "focus_height": 1.8
  },
  "px50_frost_breath": {
    "id": "px50_frost_breath",
    "name_jp": "冷気吐息",
    "family": "elements",
    "variant": "frost_breath",
    "size_class": "M",
    "life": 5.2,
    "gap": 5.6,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.1,
      5.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.3,
      4.4,
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "冷気の頭が低い床方向へ折れ後続を引く",
    "exit": "外の冷気が低い方へ進み床の縁光が別時刻に拭われる",
    "complexity_class": "S",
    "composition": {
      "main": [
        "低く曲がって抜ける冷気の房"
      ],
      "support": [
        "接地する霜の堆積跡"
      ],
      "decoration": []
    },
    "tier_reason": "冷気の主流と薄い霜の一役だけ。寸法が大きくても簡潔な構成。",
    "name": "冷気吐息",
    "number": 33,
    "focus_height": 1.8
  },
  "px50_ink_whip": {
    "id": "px50_ink_whip",
    "name_jp": "墨の鞭",
    "family": "elements",
    "variant": "ink_whip",
    "size_class": "M",
    "life": 5.4,
    "gap": 5.8,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.3,
      5.3
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.5,
      4.6,
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "暗い墨の首が前方へ振れ枝が落下する",
    "exit": "墨が低く落ち、暗い地表染みが区画順に乾く",
    "complexity_class": "S",
    "composition": {
      "main": [
        "肩から先が鞭状に落ちる墨流"
      ],
      "support": [
        "接触先へ広がる墨の染み"
      ],
      "decoration": []
    },
    "tier_reason": "墨の主流が染みへ移る一段の受渡しで、独立した装飾はない。",
    "name": "墨の鞭",
    "number": 34,
    "focus_height": 1.8
  },
  "px50_holy_spring": {
    "id": "px50_holy_spring",
    "name_jp": "聖泉",
    "family": "elements",
    "variant": "holy_spring",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "地表の文字盤から三本の癒やし流路が昇る",
    "exit": "供給停止が下から伝わり上向きの材料だけが残る",
    "complexity_class": "M",
    "composition": {
      "main": [
        "上昇する癒やしの螺旋泉"
      ],
      "support": [
        "分割して回る聖泉の地表字形",
        "遅れて現れる癒やしの十字"
      ],
      "decoration": []
    },
    "tier_reason": "主泉と、分割字形・十字の二つの別役が重なる。三つの技術層は数えない。",
    "name": "聖泉",
    "number": 35,
    "focus_height": 1.8
  },
  "px50_ember_dash": {
    "id": "px50_ember_dash",
    "name_jp": "炎の疾走",
    "family": "elements",
    "variant": "ember_dash",
    "size_class": "M",
    "life": 4.8,
    "gap": 5.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.7,
      4.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      3.9,
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "低い押し出しから前進する熱の肩と短い尾",
    "exit": "尾の供給が切れ熱い先端が進みながら冷える",
    "complexity_class": "S",
    "composition": {
      "main": [
        "二拍で通過する低い炎"
      ],
      "support": [
        "通過後の暖かい地表流跡"
      ],
      "decoration": []
    },
    "tier_reason": "二拍は主役のリズムであり別の装飾ではない。補助は熱跡一つ。",
    "name": "炎の疾走",
    "number": 36,
    "focus_height": 1.8
  },
  "px50_ether_tether": {
    "id": "px50_ether_tether",
    "name_jp": "霊気の連結",
    "family": "elements",
    "variant": "ether_tether",
    "size_class": "M",
    "life": 5.8,
    "gap": 6.2,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "両端の供給点を分けた中央の編み込み流路",
    "exit": "二つの接続点から流れが離れて中央を通過し消える",
    "complexity_class": "S",
    "composition": {
      "main": [
        "二つの供給点を往復する霊気の連結"
      ],
      "support": [
        "両端を示す同役のアンカー印"
      ],
      "decoration": []
    },
    "tier_reason": "左右供給は一つの連結現象。左右のアンカー印も一つの補助役。",
    "name": "霊気の連結",
    "number": 37,
    "focus_height": 1.8
  },
  "px50_wind_cleave": {
    "id": "px50_wind_cleave",
    "name_jp": "風の断層",
    "family": "elements",
    "variant": "wind_cleave",
    "size_class": "M",
    "life": 4.9,
    "gap": 5.3,
    "full": [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.8,
      4.8
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      4.0,
      4.1,
      4.2,
      4.3,
      4.4,
      4.5,
      4.6,
      4.7
    ],
    "peak": 1.8,
    "dist": 7,
    "description": "二枚の肩が異なる高さで前方へ剪断する",
    "exit": "肩の供給が止まり先へ抜ける尾が最後に通過",
    "complexity_class": "S",
    "composition": {
      "main": [
        "高さの異なる肩が通過する風のせん断"
      ],
      "support": [
        "地表を横切るせん断流跡"
      ],
      "decoration": []
    },
    "tier_reason": "主役の肩と地表の一役だけ。幅や層数で格上げしない。",
    "name": "風の断層",
    "number": 38,
    "focus_height": 1.8
  },
  "px50_rain_contact": {
    "id": "px50_rain_contact",
    "name_jp": "雨粒の波紋",
    "family": "elements",
    "variant": "rain_contact",
    "size_class": "S",
    "life": 3.8,
    "gap": 4.2,
    "full": [
      0.1,
      0.35,
      0.65,
      0.9,
      1.3,
      2,
      2.9,
      3.7
    ],
    "flow": [
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05,
      1.15
    ],
    "end": [
      2.9,
      3.0,
      3.1,
      3.2,
      3.3,
      3.4,
      3.5,
      3.6
    ],
    "peak": 1.1,
    "dist": 5,
    "description": "三滴の接触後に遅れた波紋が外へ走る",
    "exit": "滴が床で止まり波紋が外へ進み角度順に静まる",
    "complexity_class": "S",
    "composition": {
      "main": [
        "三滴の雨が時間差で接触"
      ],
      "support": [
        "接触から外へ進む波紋"
      ],
      "decoration": []
    },
    "tier_reason": "同じ雨の反復を主役一系統、波紋を補助一系統として数える。",
    "name": "雨粒の波紋",
    "number": 39,
    "focus_height": 0.8
  },
  "px50_leaf_swirl": {
    "id": "px50_leaf_swirl",
    "name_jp": "小葉の旋風",
    "family": "elements",
    "variant": "leaf_swirl",
    "size_class": "S",
    "life": 4.2,
    "gap": 4.6,
    "full": [
      0.1,
      0.35,
      0.65,
      0.9,
      1.3,
      2,
      3.3,
      4.1
    ],
    "flow": [
      1.0,
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7
    ],
    "end": [
      3.3,
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9,
      4.0
    ],
    "peak": 1.1,
    "dist": 5,
    "description": "低い旋回に小葉が追い付いて落ちる",
    "exit": "葉が円を離れ落下し風の尾が先へ抜ける",
    "complexity_class": "S",
    "composition": {
      "main": [
        "渦から放たれる小葉"
      ],
      "support": [
        "小葉を運ぶ短い風の流れ"
      ],
      "decoration": []
    },
    "tier_reason": "葉の数を独立した装飾に数えず、補助は風だけ。地表の輪は削除。",
    "name": "小葉の旋風",
    "number": 40,
    "focus_height": 0.8
  },
  "px50_strike_snap": {
    "id": "px50_strike_snap",
    "name": "瞬撃の火花",
    "family": "micro",
    "variant": "strike_snap",
    "size_class": "S",
    "life": 2.4,
    "gap": 2.8,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.3,
      1.6,
      2.3
    ],
    "peak": 0.42,
    "flow": [
      0.12,
      0.22,
      0.32,
      0.42,
      0.52,
      0.62,
      0.72,
      0.82
    ],
    "end": [
      0.3,
      0.4,
      0.5,
      0.6,
      0.7,
      0.8,
      0.9,
      1.0
    ],
    "dist": 5,
    "description": "五方向の短い圧力解放。先端が飛び、古い尾が遅れて追う。",
    "exit": "火流の供給を止め、後尾が前端へ追いつく。層ごとに0.038秒ずれて排出。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "放射する熱の移流"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 41,
    "focus_height": 0.8
  },
  "px50_ricochet_skip": {
    "id": "px50_ricochet_skip",
    "name": "跳弾の火流",
    "family": "micro",
    "variant": "ricochet_skip",
    "size_class": "S",
    "life": 3.1,
    "gap": 3.5,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.0,
      3.0
    ],
    "peak": 0.8,
    "flow": [
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05,
      1.15,
      1.25
    ],
    "end": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "dist": 5,
    "description": "0・0.52・0.91秒の三拍。浅くなる弧を跳ぶ熱い材料。",
    "exit": "後発の弧を残して先発から排出。弧の縮小ではなく材料が先へ抜ける。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "三拍の跳弾火流"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 42,
    "focus_height": 0.8
  },
  "px50_heal_sprout": {
    "id": "px50_heal_sprout",
    "name": "回復の芽",
    "family": "micro",
    "variant": "heal_sprout",
    "size_class": "S",
    "life": 3.8,
    "gap": 4.2,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.7,
      3.7
    ],
    "peak": 1.1,
    "flow": [
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4
    ],
    "end": [
      2.25,
      2.35,
      2.45,
      2.55,
      2.65,
      2.75,
      2.85,
      2.95
    ],
    "dist": 5,
    "description": "不等間隔の四本の芽が、横に逃げながら巻き上がる。",
    "exit": "芽が上へ抜け、根元の五弁印を区画順に払う。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "巻き上がる回復の芽"
      ],
      "support": [
        "根元の花弁印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 43,
    "focus_height": 0.8
  },
  "px50_mana_tick": {
    "id": "px50_mana_tick",
    "name": "魔力の一拍",
    "family": "micro",
    "variant": "mana_tick",
    "size_class": "S",
    "life": 3.4,
    "gap": 3.8,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.3,
      3.3
    ],
    "peak": 0.8,
    "flow": [
      0.5,
      0.6,
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2
    ],
    "end": [
      2.6,
      2.7,
      2.8,
      2.9,
      3.0,
      3.1,
      3.2,
      3.3
    ],
    "dist": 5,
    "description": "三本の螺旋流が異なる位相で上へ昇る小さな回復拍。",
    "exit": "螺旋の供給停止後も先頭が上昇し、残る印を角区画で順に閉じる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "上昇する螺旋流"
      ],
      "support": [
        "応答する床印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 44,
    "focus_height": 0.8
  },
  "px50_frost_touch": {
    "id": "px50_frost_touch",
    "name": "霜の接触",
    "family": "micro",
    "variant": "frost_touch",
    "size_class": "S",
    "life": 3.5,
    "gap": 3.9,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.4,
      3.4
    ],
    "peak": 0.65,
    "flow": [
      0.35,
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05
    ],
    "end": [
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8
    ],
    "dist": 5,
    "description": "接触点から四方向へ冷気の丸い肩が巻き返す。",
    "exit": "旧腹が上へせん断され、冷めた後尾が細まりながら流路の先へ消費。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "四方向の冷気"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 45,
    "focus_height": 0.8
  },
  "px50_ember_contact": {
    "id": "px50_ember_contact",
    "name": "残火の着弾",
    "family": "micro",
    "variant": "ember_contact",
    "size_class": "S",
    "life": 3.8,
    "gap": 4.2,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.7,
      3.7
    ],
    "peak": 0.8,
    "flow": [
      0.35,
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05
    ],
    "end": [
      1.05,
      1.15,
      1.25,
      1.35,
      1.45,
      1.55,
      1.65,
      1.75
    ],
    "dist": 5,
    "description": "四つの炎舌が異なる高さへちぎれ、遅れた熱尾が追う。",
    "exit": "発生元を切り、舌が昇りながら細り、後尾の色が暗く冷める。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "離脱する炎舌"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 46,
    "focus_height": 0.8
  },
  "px50_poison_drop": {
    "id": "px50_poison_drop",
    "name": "毒滴の着水",
    "family": "micro",
    "variant": "poison_drop",
    "size_class": "S",
    "life": 3.7,
    "gap": 4.1000000000000005,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.6,
      3.6
    ],
    "peak": 1.05,
    "flow": [
      0.75,
      0.85,
      0.95,
      1.05,
      1.15,
      1.25,
      1.35,
      1.45
    ],
    "end": [
      1.95,
      2.05,
      2.15,
      2.25,
      2.35,
      2.45,
      2.55,
      2.65
    ],
    "dist": 5,
    "description": "落下する一滴が三回の遅れた跳ね返りと床波へ渡る。",
    "exit": "滴は着地点へ、飛沫は弧の先へ抜ける。分割波紋が外へ広がって区画順に消える。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "落下して跳ねる毒滴"
      ],
      "support": [
        "接触後の分割波紋"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 47,
    "focus_height": 0.8
  },
  "px50_dust_step": {
    "id": "px50_dust_step",
    "name": "踏み出しの砂煙",
    "family": "micro",
    "variant": "dust_step",
    "size_class": "S",
    "life": 3.2,
    "gap": 3.6,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.1,
      3.1
    ],
    "peak": 0.65,
    "flow": [
      0.35,
      0.45,
      0.55,
      0.65,
      0.75,
      0.85,
      0.95,
      1.05
    ],
    "end": [
      1.1,
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8
    ],
    "dist": 5,
    "description": "踏み出しから五房の砂煙が前へずれて、複数の肩にほどける。",
    "exit": "放出を止め、茶色い房を上へ引きずりながら前へ運び出す。床を発光させない。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "上昇して希薄化する砂煙"
      ],
      "support": [],
      "decoration": []
    },
    "tier_reason": "主現象1系統に絞った構成。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 48,
    "focus_height": 0.8
  },
  "px50_rune_ping": {
    "id": "px50_rune_ping",
    "name": "刻印の応答",
    "family": "micro",
    "variant": "rune_ping",
    "size_class": "S",
    "life": 3.6,
    "gap": 4,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.5,
      3.5
    ],
    "peak": 0.9,
    "flow": [
      0.7,
      0.8,
      0.9,
      1.0,
      1.1,
      1.2,
      1.3,
      1.4
    ],
    "end": [
      2.85,
      2.95,
      3.05,
      3.15,
      3.25,
      3.35,
      3.45,
      3.55
    ],
    "dist": 5,
    "description": "三本の刻印応答が周回し、床から少しずつ持ち上がる。",
    "exit": "周回材が先端へ排出され、三枚の印が別の始点から角度順にぬぐわれる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "周回する応答流"
      ],
      "support": [
        "床の刻印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 49,
    "focus_height": 0.8
  },
  "px50_charge_seed": {
    "id": "px50_charge_seed",
    "name": "蓄勢の種",
    "family": "micro",
    "variant": "charge_seed",
    "size_class": "S",
    "life": 4.1,
    "gap": 4.5,
    "full": [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      3.0,
      4.0
    ],
    "peak": 1.25,
    "flow": [
      0.85,
      0.95,
      1.05,
      1.15,
      1.25,
      1.35,
      1.45,
      1.55
    ],
    "end": [
      3.2,
      3.3,
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9
    ],
    "dist": 5,
    "description": "四本の内向き流が中心に集まり、間を空けて上へ一度解放する。",
    "exit": "流入は中心へ消費。解放尾は上へ抜け、床印が最後に時間差で閉じる。",
    "complexity_class": "S",
    "composition": {
      "main": [
        "中心へ集まる流入と上向きの解放"
      ],
      "support": [
        "根元の菱形印"
      ],
      "decoration": []
    },
    "tier_reason": "主現象1系統と補助1系統。複数の流路・三つの描画殻は別の装飾として数えない。",
    "number": 50,
    "focus_height": 0.8
  },
  "px50_constellation_loom": {
    "id": "px50_constellation_loom",
    "name": "星図の織門",
    "family": "constellation_loom",
    "variant": "constellation_loom",
    "size_class": "L",
    "complexity_class": "L",
    "life": 6.4,
    "gap": 6.8,
    "full": [
      0.2,
      0.7,
      1.2,
      1.8,
      2.5,
      3.5,
      5.3,
      5.9
    ],
    "flow": [
      2.0,
      2.1,
      2.2,
      2.3,
      2.4,
      2.5,
      2.6,
      2.7
    ],
    "end": [
      5.0,
      5.1,
      5.2,
      5.3,
      5.4,
      5.5,
      5.6,
      5.7
    ],
    "dist": 9,
    "peak": 3.0,
    "description": "左の供給門から中央の織門、右の受け門へ、頭と尾を持つ金色の流れが到着順に起動。離れた床星図と天冠結線、三組の周回杼が別の拍で応答する。",
    "exit": "左副門→中央→右副門の四扇区交替閉鎖。闇は反向き走査、流れは排出、天冠と床星図はそれぞれ横に消し込む。",
    "composition": {
      "main": [
        "左供給門の起動",
        "中央織門の組み上げと扇区交替",
        "右受け門の到着応答"
      ],
      "support": [
        "金色の供給・送出パケット",
        "中央門の周囲を進む三組の頭尾付き杼"
      ],
      "decoration": [
        "左右から離れた床星図の時差結線",
        "上部星図の折れた天冠結線"
      ]
    },
    "tier_reason": "幅約5.5m内に三つの主展開と、連結流・周回杼・床星図・天冠結線の四補助装飾系統が別の拍と出口を持つ。門の五層は描画技術として数えない。",
    "number": 51,
    "focus_height": 1.8
  },
  "px50_echo_stitch": {
    "id": "px50_echo_stitch",
    "name": "反響の縫合",
    "nameJP": "反響の縫合",
    "family": "echo_stitch",
    "variant": "echo_stitch",
    "size_class": "M",
    "complexity_class": "M",
    "life": 6.3,
    "gap": 6.7,
    "dist": 9,
    "effect_size": 1.0,
    "full": [
      0.3,
      0.8,
      1.4,
      1.9,
      2.7,
      3.7,
      4.5,
      5.5
    ],
    "flow": [
      1.2,
      1.3,
      1.4,
      1.5,
      1.6,
      1.7,
      1.8,
      1.9
    ],
    "end": [
      4.7,
      4.8,
      4.9,
      5.0,
      5.1,
      5.2,
      5.3,
      5.4
    ],
    "peak": 1.4,
    "description": "左右交互に渡る反響の主弧を低い後続弧へ局所の縫い目で結び、到着側の開いた受け皿へ渡す。",
    "exit": "主弧と尾は供給元から進行先へ消費される。受け皿は外へ開き下へこぼれ、縫い目は後続弧へ解ける。最後の小紋は接続元から先へ抜ける。",
    "composition": {
      "main": [
        "三拍で左右を渡る反響主弧"
      ],
      "support": [
        "主弧を追う低い反響尾",
        "左右交互に開く受け皿"
      ],
      "decoration": [
        "主弧と尾の間の縫い目と接続点の局所小紋"
      ]
    },
    "tier_reason": "主役1系統に遅れた尾・交互の受け皿・局所の縫い目/小紋という3系統が因果と時差を持つ。幅約6mはL/S新作と比較する共通スケールであり分類理由ではない。",
    "number": 52,
    "focus_height": 1.8
  },
  "px50_dew_inversion": {
    "id": "px50_dew_inversion",
    "name_jp": "露の反転",
    "family": "dew_inversion",
    "variant": "dew_inversion",
    "size_class": "S",
    "complexity_class": "S",
    "composition": {
      "main": [
        "接触面で巻き返るひと筋の露"
      ],
      "support": [
        "巻き返しから前へ受け渡される一枚の薄い波"
      ],
      "decoration": []
    },
    "tier_reason": "占有領域約5〜6mでも、ひと筋の露と受渡し先の一枚波だけで構成する。技術層は数えない。",
    "life": 4.8,
    "gap": 5.2,
    "full": [
      0.15,
      0.6,
      1.05,
      1.5,
      2,
      2.6,
      3.3,
      4.3
    ],
    "flow": [
      1.5,
      1.6,
      1.7,
      1.8,
      1.9,
      2.0,
      2.1,
      2.2
    ],
    "end": [
      3.3,
      3.4,
      3.5,
      3.6,
      3.7,
      3.8,
      3.9,
      4.0
    ],
    "peak": 1.8,
    "dist": 9,
    "description": "一筋の露が接触面で巻き返り一枚の薄い波へ勢いを渡す",
    "exit": "供給元から尾が進み抜け、受け取った波は前へ排水し隆起が地表へ戻る",
    "name": "露の反転",
    "number": 53,
    "focus_height": 1.8
  }
}
const LAB_ITEMS := [
  [
    "01 深星門",
    "px50_astral_gate",
    6.4,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.5,
      4.7,
      5.5
    ]
  ],
  [
    "02 月蝕門",
    "px50_eclipse_gate",
    6.4,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.5,
      4.7,
      5.5
    ]
  ],
  [
    "03 潮汐門",
    "px50_tidal_gate",
    6.6,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.7,
      4.9,
      5.7
    ]
  ],
  [
    "04 裂晶門",
    "px50_fractured_gate",
    6.5,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.6,
      4.8,
      5.6
    ]
  ],
  [
    "05 召喚井戸",
    "px50_summon_well",
    6.2,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.3,
      4.5,
      5.3
    ]
  ],
  [
    "06 六角転送",
    "px50_hex_door",
    6.1,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.2,
      4.4,
      5.2
    ]
  ],
  [
    "07 位相窓",
    "px50_phase_window",
    6.2,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.3,
      4.5,
      5.3
    ]
  ],
  [
    "08 双門",
    "px50_twin_gate",
    6.6,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.7,
      4.9,
      5.7
    ]
  ],
  [
    "09 刻印門",
    "px50_rune_gate",
    6.3,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      3.4,
      4.6,
      5.4
    ]
  ],
  [
    "10 瞬間裂け目",
    "px50_blink_rift",
    3.9,
    [
      0.1,
      0.4,
      0.8,
      1.0,
      1.2,
      1.8,
      2.2,
      3.0
    ]
  ],
  [
    "11 帰還印",
    "px50_return_mark",
    5.0,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      2.1,
      3.3,
      4.1
    ]
  ],
  [
    "12 宝の小門",
    "px50_loot_aperture",
    5.3,
    [
      0.1,
      0.4,
      0.8,
      1.2,
      1.8,
      2.4,
      3.6,
      4.4
    ]
  ],
  [
    "13 業火の開裂",
    "px50_inferno_bloom",
    6.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ]
  ],
  [
    "14 彗星衝突",
    "px50_comet_crash",
    6.2,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ]
  ],
  [
    "15 嵐の冠",
    "px50_storm_crown",
    6.2,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ]
  ],
  [
    "16 凍結大崩壊",
    "px50_frost_cataclysm",
    6.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ]
  ],
  [
    "17 重力崩落",
    "px50_gravity_collapse",
    6.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ]
  ],
  [
    "18 地裂噴圧",
    "px50_earth_rift",
    6.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ]
  ],
  [
    "19 プラズマ破砕",
    "px50_plasma_breaker",
    6.2,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.6,
      5.25
    ]
  ],
  [
    "20 大潮撃",
    "px50_tidal_slam",
    6.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      5.0,
      5.65
    ]
  ],
  [
    "21 炎槍",
    "px50_fire_lance",
    5.4,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      3.8,
      4.45
    ]
  ],
  [
    "22 氷弾",
    "px50_ice_shot",
    5.4,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      3.8,
      4.45
    ]
  ],
  [
    "23 連鎖雷",
    "px50_chain_arc",
    5.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.0,
      4.65
    ]
  ],
  [
    "24 交差斬",
    "px50_cross_cut",
    5.6,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.0,
      4.65
    ]
  ],
  [
    "25 障壁破断",
    "px50_shield_break",
    6.0,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.4,
      5.05
    ]
  ],
  [
    "26 音圧拳",
    "px50_sonic_punch",
    6.0,
    [
      0.2,
      0.65,
      1.1,
      1.6,
      2.2,
      3.1,
      4.4,
      5.05
    ]
  ],
  [
    "27 極光螺旋",
    "px50_aurora_spiral",
    6.6,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      5.1,
      6.1
    ]
  ],
  [
    "28 火山噴口",
    "px50_volcanic_vent",
    6.2,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ]
  ],
  [
    "29 砂塵の大渦",
    "px50_sand_maelstrom",
    6.4,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.9,
      5.9
    ]
  ],
  [
    "30 残火の奔流",
    "px50_ember_surge",
    5.4,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.9,
      4.9
    ]
  ],
  [
    "31 折り返し滝",
    "px50_waterfall_fold",
    6.0,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.5,
      5.5
    ]
  ],
  [
    "32 毒霧吐息",
    "px50_poison_breath",
    5.6,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.1,
      5.1
    ]
  ],
  [
    "33 冷気吐息",
    "px50_frost_breath",
    5.6,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.1,
      5.1
    ]
  ],
  [
    "34 墨の鞭",
    "px50_ink_whip",
    5.8,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.3,
      5.3
    ]
  ],
  [
    "35 聖泉",
    "px50_holy_spring",
    6.2,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ]
  ],
  [
    "36 炎の疾走",
    "px50_ember_dash",
    5.2,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.7,
      4.7
    ]
  ],
  [
    "37 霊気の連結",
    "px50_ether_tether",
    6.2,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      4.7,
      5.7
    ]
  ],
  [
    "38 風の断層",
    "px50_wind_cleave",
    5.3,
    [
      0.1,
      0.5,
      1,
      1.8,
      2.6,
      3.4,
      3.8,
      4.8
    ]
  ],
  [
    "39 雨粒の波紋",
    "px50_rain_contact",
    4.2,
    [
      0.1,
      0.35,
      0.65,
      0.9,
      1.3,
      2,
      2.9,
      3.7
    ]
  ],
  [
    "40 小葉の旋風",
    "px50_leaf_swirl",
    4.6,
    [
      0.1,
      0.35,
      0.65,
      0.9,
      1.3,
      2,
      3.3,
      4.1
    ]
  ],
  [
    "41 瞬撃の火花",
    "px50_strike_snap",
    2.8,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.3,
      1.6,
      2.3
    ]
  ],
  [
    "42 跳弾の火流",
    "px50_ricochet_skip",
    3.5,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.0,
      3.0
    ]
  ],
  [
    "43 回復の芽",
    "px50_heal_sprout",
    4.2,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.7,
      3.7
    ]
  ],
  [
    "44 魔力の一拍",
    "px50_mana_tick",
    3.8,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.3,
      3.3
    ]
  ],
  [
    "45 霜の接触",
    "px50_frost_touch",
    3.9,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.4,
      3.4
    ]
  ],
  [
    "46 残火の着弾",
    "px50_ember_contact",
    4.2,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.7,
      3.7
    ]
  ],
  [
    "47 毒滴の着水",
    "px50_poison_drop",
    4.1000000000000005,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.6,
      3.6
    ]
  ],
  [
    "48 踏み出しの砂煙",
    "px50_dust_step",
    3.6,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.1,
      3.1
    ]
  ],
  [
    "49 刻印の応答",
    "px50_rune_ping",
    4,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      2.5,
      3.5
    ]
  ],
  [
    "50 蓄勢の種",
    "px50_charge_seed",
    4.5,
    [
      0.08,
      0.25,
      0.5,
      0.8,
      1.15,
      1.6,
      3.0,
      4.0
    ]
  ],
  [
    "51 星図の織門",
    "px50_constellation_loom",
    6.8,
    [
      0.2,
      0.7,
      1.2,
      1.8,
      2.5,
      3.5,
      5.3,
      5.9
    ]
  ],
  [
    "52 反響の縫合",
    "px50_echo_stitch",
    6.7,
    [
      0.3,
      0.8,
      1.4,
      1.9,
      2.7,
      3.7,
      4.5,
      5.5
    ]
  ],
  [
    "53 露の反転",
    "px50_dew_inversion",
    5.2,
    [
      0.15,
      0.6,
      1.05,
      1.5,
      2,
      2.6,
      3.3,
      4.3
    ]
  ]
]
