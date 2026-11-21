#!/usr/bin/env python3
"""从锁定 Unity 源提取原头部工作台合同，不复制原始素材。"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from extract_formal_human_animation import SOURCE, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
ART = "Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/"
DIRECTIONS = ("SE", "SW", "NE", "NW")
FILENAMES = ["HelmetDesigns.png", "鹿头盔.png"] + [f"鹿头盔{i}.png" for i in range(2, 5)] + [f"hat_yellow{i}.png" for i in range(1, 5)] + [f"glasses{i}.png" for i in range(1, 4)]
NAMES = {"角饰头盔", "铁盔 I", "铁盔 II", "轻帽", "护目镜"}


def extract(repo, directory):
    catalog = ROOT + "Data/Workbench/换装工作台目录.asset"
    raw = read(repo, catalog)
    sources = {catalog: hashlib.sha256(raw).hexdigest()}
    options = parse(raw)["MonoBehaviour"]["equipments"]
    textures = {}
    sprites = {}
    for name in FILENAMES:
        data = (directory / name).read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        pinned = read(repo, ART + name)
        if pinned.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            lines = pinned.decode().splitlines()
            assert f"oid sha256:{sha}" in lines and f"size {len(data)}" in lines, name
        else:
            assert data == pinned, name
        assert data[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
        size = struct.unpack(">II", data[16:24])
        meta = parse(read(repo, ART + name + ".meta"))
        guid = meta["guid"]
        imp = meta["TextureImporter"]
        assert imp["textureSettings"]["filterMode"] == 0
        assert size == ((512, 608) if name == "HelmetDesigns.png" else (32, 32))
        textures[guid] = {"file": name, "sha256": sha, "size": list(size)}
        if imp["spriteMode"] == 1:
            sprites[(guid, 21300000)] = dict(x=0, y=0, width=size[0], height=size[1])
        else:
            assert imp["spriteMode"] == 2
            for entry in imp["spriteSheet"]["sprites"]:
                sprites[(guid, entry["internalID"])] = entry["rect"]
    selected = []
    for option in options:
        name = option["displayName"]
        if name not in NAMES:
            continue
        path = ROOT + "Equip/Visual/" + name + ".asset"
        raw = read(repo, path)
        sources[path] = hashlib.sha256(raw).hexdigest()
        visual = parse(raw)["MonoBehaviour"]
        guid = parse(read(repo, path + ".meta"))["guid"]
        assert guid == option["visual"]["guid"]
        assert visual["type"] in (5, 6, 7) and not visual["animSequences"]
        for variant in ("up", "down", "left", "right"):
            assert all(visual[variant + "Variant"][d.lower()]["fileID"] == 0 for d in DIRECTIONS)
        slices = []
        for direction in DIRECTIONS:
            ref = visual["sprite" + direction]
            texture = textures[ref["guid"]]
            crop = sprites[(ref["guid"], ref["fileID"])]
            x, y, w, h = [crop[k] for k in ("x", "y", "width", "height")]
            iw, ih = texture["size"]
            assert (w, h) == (32, 32) and 0 <= x <= iw - w and 0 <= y <= ih - h
            assert x == int(x) and y == int(y)
            slices.append({"texture": ref["guid"], "rect": [int(x), int(y), 32, 32], "file_id": str(ref["fileID"])})
        selected.append(dict(name=name, guid=guid, type=visual["type"], hide_hair=bool(visual["hideHair"]),
                             hide_beard=bool(visual["hideBeard"]), stats=option["bonusStats"]["values"], directions=slices))
    assert {o["name"] for o in selected} == NAMES and len(selected) == len(NAMES)
    return dict(source_commit=SOURCE, sources=sources, textures=textures, options=selected)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", type=Path)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    result = extract(args.repo, args.directory)
    (args.directory / "headwear.json").write_bytes((json.dumps(result, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
    for option in result["options"]:
        print(option["name"], option["type"], int(option["hide_hair"]), int(option["hide_beard"]), option["stats"],
              [(result["textures"][s["texture"]]["file"], s["rect"][:2]) for s in option["directions"]])
