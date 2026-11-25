"""核算精确 Dwarf/Elf 原躯干披风采样；不输出图像。"""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("characters", type=Path, help="锁定的 dwarf-elf-audit.json")
parser.add_argument("cloaks", type=Path, help="启用全人类预览的锁定 cloak.json")
parser.add_argument("output", type=Path, help="私有测试合同文件；不要提交")
args = parser.parse_args()
def read(path, sha):
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == sha
    return json.loads(raw)

actors = read(args.characters,
              "9c92d86d0ae0fcd27ec6b550bcb9ef8860f570efe6fd407bec2df87eb7e932fe")
catalog = read(args.cloaks,
               "17dbddabcdbaa3018d18bcfd3b3a13ed66927c5c9f7db52e6a5e5853a811f052")
assert actors["source_commit"] == catalog["source_commit"] == "31629d53a110dd4c87d4c85e6ad5a387fbafb931"

def pick(sets, facing, variant):
    order = ((0,), (1, 0), (2, 0), (3, 1, 0))[facing]
    if variant and sets[variant][0]:
        for index in order:
            if sets[variant][index]:
                return sets[variant][index]
    return next(sets[0][index] for index in order if sets[0][index])

matrix = {}
for race, data in actors["characters"].items():
    actions = {}
    counts = Counter()
    for action, spec in data["actions"].items():
        rows = []
        by_cell = {(r["frameIndex"], r["rowIndex"]): r for r in spec["frames"]}
        assert len(by_cell) == len(spec["frames"])
        for d, frames in enumerate(spec["directions"]):
            for label in dict.fromkeys(spec["labels"]):
                asset = frames[label]
                sx, sy, w, h = asset["rect"]
                assert w == h == 32 and sx % w == sy % h == 0
                row = spec["frame_rows"] - sy // h - 1
                col = sx // w
                record = by_cell.get((col, row), {})
                torso = next((p for p in record.get("bodyRegions", []) if p["part"] == 1), None)
                facing, variant = (torso["spriteFacing"], torso["variant"]) if torso else (row, 0)
                counts[(facing, variant, torso is not None, d != row)] += 1
                guids = [pick(o["sprite_sets"], facing, variant) for o in catalog["options"]]
                rows.append([d, label, row, col, facing, variant, *guids])
        actions[action] = rows
    assert len(actions) == 14 and sum(counts.values()) == 408
    assert not any(key[1] for key in counts)
    print(race, dict(counts), "408 实际帧采样 × 2 件披风")
    matrix[race] = actions
heavy = catalog["options"][1]["sprite_sets"]
synthetic = {str(k): catalog["textures"][pick(heavy, 3, k)]["file"] for k in range(5)}
assert synthetic == {"0":"斗篷1.png","1":"斗篷1.png","2":"斗篷1.png","3":"clock8.png","4":"斗篷1.png"}
matrix["synthetic_heavy_nw"] = synthetic
args.output.write_text(json.dumps(matrix,separators=(",",":"),ensure_ascii=False)+"\n")
print("厚斗篷 NW，Base/Up/Down/Left/Right:", synthetic)
