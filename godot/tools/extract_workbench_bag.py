#!/usr/bin/env python3
"""从锁定 Unity 源提取小背包图集合同，不复制原始素材。"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from extract_formal_human_animation import SOURCE, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
ART = "Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/"
DIRECTIONS = ("SE", "SW", "NE", "NW")


def extract(repo, directory):
    visual = ROOT + "Equip/Visual/小背包.asset"
    catalog = ROOT + "Data/Workbench/换装工作台目录.asset"
    asset = parse(read(repo, visual))["MonoBehaviour"]
    guid = parse(read(repo, visual + ".meta"))["guid"]
    option = next(o for o in parse(read(repo, catalog))["MonoBehaviour"]["equipments"] if o["visual"]["guid"] == guid)
    assert asset["type"] == 10 and not asset["animSequences"]
    for variant in ("up", "down", "left", "right"):
        assert all(asset[variant + "Variant"][d.lower()]["fileID"] == 0 for d in DIRECTIONS)
    textures = {}
    sprites = {}
    for side in ("front", "back"):
        name = f"YellowBackpacks_facing{side}.png"
        data = (directory / name).read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        pointer = read(repo, ART + name).decode().splitlines()
        assert f"oid sha256:{sha}" in pointer and f"size {len(data)}" in pointer, name
        assert data[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
        size = struct.unpack(">II", data[16:24])
        assert size == (160, 128)
        meta = parse(read(repo, ART + name + ".meta"))
        imp = meta["TextureImporter"]
        assert imp["textureSettings"]["filterMode"] == 0
        textures[meta["guid"]] = {"file": name, "sha256": sha, "size": list(size)}
        for entry in imp["spriteSheet"]["sprites"]:
            sprites[(meta["guid"], entry["internalID"])] = entry["rect"]
    slices = []
    for direction in DIRECTIONS:
        ref = asset["sprite" + direction]
        crop = sprites[(ref["guid"], ref["fileID"])]
        x, y, w, h = [crop[k] for k in ("x", "y", "width", "height")]
        assert (w, h) == (32, 32) and 0 <= x <= 128 and 0 <= y <= 96
        assert x == int(x) and y == int(y)
        slices.append({"texture": ref["guid"], "rect": [int(x), int(y), 32, 32], "file_id": str(ref["fileID"])})
    assert option["bonusStats"]["values"] == [{"stat": 1, "value": 2}, {"stat": 4, "value": 3}]
    return dict(source_commit=SOURCE, visual_guid=guid, name=option["displayName"],
                description=option["description"], stats=option["bonusStats"]["values"],
                textures=textures, directions=slices)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", type=Path, help="包含锁定提交的 Unity Git 仓库")
    parser.add_argument("directory", type=Path, help="包含私有、已授权的两张背包 PNG")
    args = parser.parse_args()
    result = extract(args.repo, args.directory)
    (args.directory / "bag.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
