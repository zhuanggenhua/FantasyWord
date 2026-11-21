#!/usr/bin/env python3
"""核对正式战马骑手帧、Body/Head UV 与工作台基础布衣引用。"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from extract_formal_human_animation import SOURCE, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
FRAME = ROOT + "FrameData/人类战马骑乘帧数据.asset"
MOUNT = ROOT + "Mounts/战马_人类骑乘表现.asset"
CLOTH = ROOT + "Equip/Visual/布衣.asset"
CLOTH_ITEM = "Assets/Database/Items/Equipment/基础布衣.asset"
BASE_PREFAB = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
LOOK = ROOT + "Appearance/基础人形外观.asset"
MAPS = ROOT + "GeneratedUV/Mounts/HumanWarHorse/"

def extract(repo, directory):
    plain = json.loads((directory / "plain-horse-source.json").read_text())
    assert plain["source"] == SOURCE
    frame_source = read(repo, FRAME)
    mount = parse(read(repo, MOUNT))["MonoBehaviour"]
    guid = parse(read(repo, FRAME + ".meta"))["guid"]
    assert mount["riderFrameData"]["guid"] == guid == "249c37077853fce439d792d673d132bb"
    cloth_guid = parse(read(repo, CLOTH + ".meta"))["guid"]
    cloth = parse(read(repo, CLOTH))["MonoBehaviour"]
    item = parse(read(repo, CLOTH_ITEM))["MonoBehaviour"]
    assert item["m_visual"]["guid"] == cloth_guid and item["m_type"] == cloth["type"] == 2
    assert all(cloth["sprite" + f] == {"fileID": 21300000, "guid": "61b4d03146f44454296aff8e68732164", "type": 3}
               for f in ("SE", "SW", "NE", "NW"))
    assert not cloth["hideHair"] and not cloth["hideBeard"]
    assert all(not value["fileID"] for k in ("up", "down", "left", "right") for value in cloth[k+"Variant"].values())
    look_guid = parse(read(repo, LOOK + ".meta"))["guid"]
    assert f"appearance: {{fileID: 11400000, guid: {look_guid}, type: 2}}" in read(repo, BASE_PREFAB).decode()
    useful = ("    spritesheet:", "    frameSize:", "    framesPerRow:", "    rowCount:",
              "    bodyUVMap:", "    headUVMap:", "    frames:", "    - frameIndex:",
              "      rowIndex:", "      bodyRegions:", "      - part:", "        spriteFacing:",
              "      leftEyeClosed:", "      rightEyeClosed:")
    authored = frame_source.decode().split("\n  - animationType: ")[1:]
    actions = {}
    for key, animation, columns in [("Stand", "Idle", 12), ("Move", "Walk", 4)]:
        pairs = plain["actions"][key]["directions"]
        atlas_guid = pairs[0][0]["rider"]["atlas"]
        block, = (r for r in authored if f"spritesheet: {{fileID: 2800000, guid: {atlas_guid}," in r)
        lines = block.splitlines()
        cfg = parse(("- animationType: "+lines[0]+'\n'+'\n'.join(line[2:] for line in lines[1:] if line.startswith(useful))).encode())[0]
        assert cfg["animationType"] == next(a["animationType"] for a in mount["animations"] if a["mountAction"] == (1 if key=="Stand" else 2))
        assert cfg["frameSize"] == {"x": 32, "y": 32} and cfg["framesPerRow"] == columns and cfg["rowCount"] == 4
        result = {"frames": [], "atlas": atlas_guid}
        for layer in ("Body", "Head"):
            name = f"HumanWarHorse_{animation}_{layer}UV.png"
            path = MAPS + name
            meta = parse(read(repo, path+'.meta'))
            importer = meta["TextureImporter"]
            ref = cfg[layer.lower() + "UVMap"]
            assert meta["guid"] == ref["guid"] and ref["fileID"] == 2800000
            assert not importer["mipmaps"]["sRGBTexture"] and not importer["mipmaps"]["enableMipMap"]
            assert importer["textureSettings"]["filterMode"] == 0
            raw = (directory / name).read_bytes()
            sha = hashlib.sha256(raw).hexdigest()
            pinned = read(repo, path)
            if pinned.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
                assert f"oid sha256:{sha}" in pinned.decode() and f"size {len(raw)}" in pinned.decode()
            else:
                assert raw == pinned
            size = list(struct.unpack(">II", raw[16:24]))
            assert raw[:8] == b"\x89PNG\r\n\x1a\n" and size == [32 * columns, 128]
            assert size == plain["atlases"][atlas_guid]["size"]
            result[layer.lower()] = dict(file=name, sha256=sha, size=size)
        seen = set()
        for row in cfg["frames"]:
            x,y = row["frameIndex"], row["rowIndex"]
            assert (x,y) not in seen
            seen.add((x,y))
            regions = {}
            for region in row["bodyRegions"]:
                part = {0:"head", 1:"torso"}.get(region["part"])
                if part is not None and part not in regions:
                    regions[part] = {"sprite_facing": region["spriteFacing"]}
            result["frames"].append(dict(frame_index=x,row_index=y,body_regions=regions,
                                         left_eye_closed=bool(row["leftEyeClosed"]),
                                         right_eye_closed=bool(row["rightEyeClosed"])))
        assert seen == {(pair["rider"]["rect"][0]//32, pair["rider"]["rect"][1]//32) for direction in pairs for pair in direction}
        actions[key] = result
    return dict(source=SOURCE, frame_guid=guid, frame_sha256=hashlib.sha256(frame_source).hexdigest(),
                cloth_guid=cloth_guid, appearance_guid=look_guid, actions=actions)

if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("repo", type=Path)
    cli.add_argument("private_directory", type=Path)
    args = cli.parse_args()
    data = extract(args.repo, args.private_directory)
    path = args.private_directory / "mounted-cloth-source.json"
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding="utf-8")
    print("已核对骑手四张原 UV 图与 64 个帧数据，合同 SHA-256：",hashlib.sha256(path.read_bytes()).hexdigest())
