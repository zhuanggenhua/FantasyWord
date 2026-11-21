#!/usr/bin/env python3
"""Extract the original human anchors and the spear / heavy shield workbench contract."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

from extract_formal_human_animation import SOURCE, ROOT as ANIMATION_ROOT, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
ART = "Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/"
HUMAN_ART = "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human/Human/"
DIRECTIONS = ("SE", "SW", "NE", "NW")
ACTIONS = {"Idle": 16, "Walk": 4, "Attack": 4, "Dmg": 4}


def extract(repo, directory):
    textures, sprites, sources = {}, {}, {}
    for name in ("长矛1.png", "shield2.png", "shield3.png", "shield4.png", "shield5.png", "Slash_sword_f.png", "Slash_sword_b.png"):
        path = (HUMAN_ART if name.startswith("Slash_") else ART) + name
        data = (directory / name).read_bytes()
        sha = hashlib.sha256(data).hexdigest()
        pinned = read(repo, path)
        if pinned.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            lines = pinned.decode().splitlines()
            assert f"oid sha256:{sha}" in lines and f"size {len(data)}" in lines, name
        else:
            assert data == pinned, name
        assert data[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
        size = struct.unpack(">II", data[16:24])
        meta = parse(read(repo, path + ".meta"))
        guid = meta["guid"]
        imp = meta["TextureImporter"]
        assert imp["textureSettings"]["filterMode"] == 0
        textures[guid] = {"file": name, "sha256": sha, "size": list(size)}
        if imp["spriteMode"] == 1:
            sprites[(guid, 21300000)] = (0, 0, *size)
        else:
            assert imp["spriteMode"] == 2
            for row in imp["spriteSheet"]["sprites"]:
                sprites[(guid, row["internalID"])] = tuple(int(row["rect"][k]) for k in ("x", "y", "width", "height"))

    def src(path):
        raw = read(repo, path)
        sources[path] = hashlib.sha256(raw).hexdigest()
        return raw

    def sprite(ref):
        if ref["fileID"] == 0:
            return None
        guid, file_id = ref["guid"], ref["fileID"]
        x, y, w, h = sprites[(guid, file_id)]
        iw, ih = textures[guid]["size"]
        assert w > 0 and h > 0 and 0 <= x <= iw-w and 0 <= y <= ih-h
        return dict(texture=guid, file_id=str(file_id), rect=[x, y, w, h])

    catalog = parse(src(ROOT + "Data/Workbench/换装工作台目录.asset"))["MonoBehaviour"]["equipments"]
    attack_guid = parse(src(ROOT + "AnimationType/Attack.asset.meta"))["guid"]
    options = []
    for i, name in enumerate(("长矛", "重盾")):
        path = ROOT + f"Equip/Visual/{name}.asset"
        definition = parse(src(path).replace(b"depthModes: ", b"depthModes: !!str "))["MonoBehaviour"]
        guid = parse(src(path + ".meta"))["guid"]
        option = next(o for o in catalog if o["visual"]["guid"] == guid)
        assert option["displayName"] == name
        assert definition["type"] == 8+i and definition["weaponSlotType"] == (0 if i==0 else 3)
        assert not definition["useOffHandAnchor"] and not definition["hideOutlineOnBody"]
        directions = [sprite(definition["sprite"+d]) for d in DIRECTIONS]
        sequences = {}
        for seq in definition["animSequences"]:
            assert i == 0 and seq["animationType"]["guid"] == attack_guid and len(seq["strips"]) == 4
            rows = [None]*4
            for strip in seq["strips"]:
                row = strip["facing"]
                frames = [sprite(r) for r in strip["frames"]]
                depth = [n for (n,) in struct.iter_unpack("<I",bytes.fromhex(strip["depthModes"]))]
                assert len(frames) == len(depth) == 4 and depth == ([0]*4 if row < 2 else [0,0,1,1])
                assert all(r["rect"] == [j*32,(3-row)*32,32,32] for j,r in enumerate(frames))
                rows[row] = [dict(sprite=r, depth_back=bool(d)) for r,d in zip(frames,depth)]
            sequences["Attack"] = rows
        assert len(sequences) == (1 if i==0 else 0)
        options.append(dict(name=name, guid=guid, type=definition["type"], stats=option["bonusStats"]["values"],
                            directions=directions, sequences=sequences))

    frame_path = ROOT + "FrameData/人类帧数据.asset"
    frame_records = src(frame_path).decode().split("\n  - animationType: ")[1:]
    frames = {}
    wanted = ("    frameSize:", "    frames:", "    - frameIndex:", "      rowIndex:", "      anchors:",
              "      - type:", "        position:", "        direction:", "      bodyRegions:", "      - part:", "        spriteFacing:")
    for key,count in ACTIONS.items():
        guid = parse(src(ROOT + f"AnimationType/{key}.asset.meta"))["guid"]
        record, = (r for r in frame_records if guid in r.splitlines()[0])
        parts = record.splitlines()
        compact = "\n".join(["- animationType: "+parts[0]]+[l[2:] for l in parts[1:] if l.startswith(wanted)])
        data = parse(compact.encode())[0]
        assert data["frameSize"] == {"x":32,"y":32}
        rows = []
        for row in data["frames"]:
            label, ri = row["frameIndex"],row["rowIndex"]
            torso = next((p["spriteFacing"] for p in row["bodyRegions"] if p["part"]==1),ri)
            anchors = [None,None]
            for rec in row["anchors"]:
                idx=rec["type"]
                assert idx in (0,1) and anchors[idx] is None
                anchors[idx] = [rec["position"]["x"],rec["position"]["y"],rec["direction"]]
            rows.append([label,ri,torso,*anchors])
        assert {(r[0],r[1]) for r in rows} == {(label,row) for label in range(count) for row in range(4)}
        frames[key] = rows
    return dict(source_commit=SOURCE, sources=sources, textures=textures, options=options, frames=frames)


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo",type=Path)
    parser.add_argument("directory",type=Path)
    args=parser.parse_args()
    result=extract(args.repo,args.directory)
    (args.directory/"weapons.json").write_bytes((json.dumps(result,indent=2,ensure_ascii=False)+"\n").encode("utf-8"))
