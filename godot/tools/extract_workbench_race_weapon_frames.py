#!/usr/bin/env python3
"""从锁定版本的角色目录和帧数据提取武器定位表；输出仅供本地工作台使用。"""
import argparse
import hashlib
import json
from pathlib import Path

from extract_formal_human_animation import SOURCE, parse, read

BASE = "Assets/GameData/EquipmentSystem/"
RACES = {"Dwarf": "矮人", "Elf": "精灵", "Goblin": "地精", "Orc": "兽人"}


def extract(repo):
    def asset(path):
        return parse(read(repo, BASE + path))["MonoBehaviour"]

    def guid(path):
        return parse(read(repo, BASE + path + ".meta"))["guid"]

    catalog_path = "Data/Workbench/换装工作台目录.asset"
    assert guid(catalog_path).encode() in read(repo, "Assets/Scenes/EquipmentSystemDemo.unity")
    catalog = asset(catalog_path)
    animation_types = repo / BASE / "AnimationType"
    type_by_guid = {
        guid(f"AnimationType/{p.name}"): p.stem
        for p in sorted(animation_types.glob("*.asset"))
        if p.stem != "AnimationTypeDatabase"
    }
    data = {"source_commit": SOURCE, "races": {}}
    for race, name in RACES.items():
        path = f"FrameData/{name}帧数据.asset"
        character, = (entry for entry in catalog["characters"] if entry["displayName"] == name)
        assert character["frameData"]["guid"] == guid(path)
        raw = read(repo, BASE + path)
        actions = {}
        for block in parse(raw)["MonoBehaviour"]["animations"]:
            key = type_by_guid[block["animationType"]["guid"]]
            assert key not in actions and block["frameSize"] == {"x": 32, "y": 32}
            table = {}
            for entry in block["frames"]:
                row, column = int(entry["rowIndex"]), int(entry["frameIndex"])
                assert 0 <= row < block["rowCount"] and 0 <= column < block["framesPerRow"]
                assert (row, column) not in table
                anchors = {}
                for anchor in entry["anchors"] or []:
                    kind = anchor["type"]
                    if kind not in (0, 1):
                        continue
                    assert kind not in anchors and 0 <= anchor["direction"] < 8
                    x, y = anchor["position"]["x"], anchor["position"]["y"]
                    assert x == int(x) and y == int(y)
                    anchors[kind] = [int(x), int(y), anchor["direction"]]
                facing = next(
                    (region["spriteFacing"] for region in entry["bodyRegions"] or [] if region["part"] == 1),
                    row,
                )
                assert facing in range(4)
                table[(row, column)] = [row, column, facing, anchors.get(0), anchors.get(1)]
            assert len(table) == block["rowCount"] * block["framesPerRow"]
            actions[key] = [table[offset] for offset in sorted(table)]
        data["races"][race] = {"frame_sha256": hashlib.sha256(raw).hexdigest(), "actions": actions}
    return data


if __name__ == "__main__":
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("repo", type=Path)
    args.add_argument("output", type=Path, help="写入不纳入版本控制的私有输出目录")
    a = args.parse_args()
    raw = (json.dumps(extract(a.repo), sort_keys=True, separators=(",", ":")) + "\n").encode()
    digest = hashlib.sha256(raw).hexdigest()
    assert digest == "54333050a57fd88fa451b111ec5f0e2cd5de1e739a73218726beb9f81bcacade"
    a.output.write_bytes(raw)
    print("已提取锁定四族的原武器挂点与帧朝向。")
