#!/usr/bin/env python3
"""Extract the original human anchors and the original two main-hand and two off-hand options."""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

from extract_formal_human_animation import SOURCE, ROOT as ANIMATION_ROOT, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
ART = "Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/"
HUMAN_ART = "Assets/Art/MINIFANTASY Creatures - Super Low Res 2D Pixel Art by Krishna Palacio/Sprites/Humanoids/Human/Human/"
AXE_ART = "Assets/Art/武器/迷你幻想_武器_v3.0/迷你幻想_武器_素材/劈砍_攻击/斧/"
DIRECTIONS = ("SE", "SW", "NE", "NW")
ACTIONS = {"Idle": 16, "Walk": 4, "Attack": 4, "Dmg": 4}


def extract(repo, directory, legacy_pair=False, spear_only=False):
    textures, sprites, sources = {}, {}, {}
    names = ["长矛1.png"]
    if not spear_only:
        names += ["shield2.png", "shield3.png", "shield4.png", "shield5.png"]
    names += ["Slash_sword_f.png", "Slash_sword_b.png"]
    if not legacy_pair and not spear_only:
        names.extend(["axe.png", "shield.png", "shield0.png", "劈砍_斧_f.png", "劈砍_斧_b.png"])
    for name in names:
        path = (HUMAN_ART if name.startswith("Slash_") else AXE_ART if name.startswith("劈砍_斧") else ART) + name
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
    slash_guid = None if legacy_pair or spear_only else parse(src(ROOT + "AnimationType/SlashAttack.asset.meta"))["guid"]
    options = []
    names = ("长矛",) if spear_only else (("长矛", "重盾") if legacy_pair else ("战斧", "长矛", "重盾", "圆盾"))
    for name in names:
        path = ROOT + f"Equip/Visual/{name}.asset"
        definition = parse(src(path).replace(b"depthModes: ", b"depthModes: !!str "))["MonoBehaviour"]
        guid = parse(src(path + ".meta"))["guid"]
        option = next(o for o in catalog if o["visual"]["guid"] == guid)
        assert option["displayName"] == name
        main_hand = name in ("战斧", "长矛")
        assert definition["type"] == (8 if main_hand else 9) and definition["weaponSlotType"] == (0 if main_hand else 3)
        assert not any(definition[v+"Variant"][d.lower()]["fileID"] != 0 for v in ("up","down","left","right") for d in DIRECTIONS)
        assert not definition["useOffHandAnchor"] and not definition["hideOutlineOnBody"]
        directions = [sprite(definition["sprite"+d]) for d in DIRECTIONS]
        sequences = {}
        for seq in definition["animSequences"]:
            key_guid = seq["animationType"]["guid"]
            assert main_hand and len(seq["strips"]) == 4
            if key_guid == slash_guid:
                assert name == "战斧" and seq["strips"] == next(a["strips"] for a in definition["animSequences"] if a["animationType"]["guid"] == attack_guid)
                continue  # No SlashAttack body animation is exposed by this scene yet.
            assert key_guid == attack_guid
            rows = [None]*4
            for strip in seq["strips"]:
                row = strip["facing"]
                frames = [sprite(r) for r in strip["frames"]]
                depth = [n for (n,) in struct.iter_unpack("<I",bytes.fromhex(strip["depthModes"]))]
                assert len(frames) == len(depth) == 4 and depth == ([0]*4 if row < 2 else [0,0,1,1])
                columns = [1,0,2,3] if name == "战斧" and row == 2 else range(4)
                assert all(r["rect"] == [j*32,(3-row)*32,32,32] for j,r in zip(columns,frames))
                rows[row] = [dict(sprite=r, depth_back=bool(d)) for r,d in zip(frames,depth)]
            sequences["Attack"] = rows
        assert len(sequences) == int(main_hand)
        assert [r is not None for r in directions] == {
            "战斧":[True,False,False,False], "长矛":[True,False,False,False],
            "重盾":[True]*4, "圆盾":[True,True,False,False]
        }[name]
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

def extract_primary_spear(repo, directory):
    source = extract(repo, directory, spear_only=True)
    item_path = "Assets/Database/Items/Equipment/长矛.asset"
    item_guid = parse(read(repo, item_path + ".meta"))["guid"]
    assert item_guid == "e75ab3eda87066246bf3a27034a417bd"
    equipment = parse(read(repo, item_path))["MonoBehaviour"]
    original = next(item for item in source["options"] if item["name"] == "长矛")
    assert equipment["m_type"] == 0 and equipment["m_visual"]["guid"] == original["guid"]
    assert list(original["sequences"].keys()) == ["Attack"]
    assert all(row[3] is not None for frames in source["frames"].values() for row in frames)
    # The actual formal death atlas is 12 columns and a single row. The
    # source has no weapon anchor in these 12 frames or unused facing rows.
    spin_guid = parse(read(repo, ROOT + "AnimationType/SpinDie.asset.meta"))["guid"]
    raw = read(repo, ROOT + "FrameData/人类帧数据.asset").decode()
    spin, = [record for record in raw.split("\n  - animationType: ")[1:]
             if spin_guid in record.splitlines()[0]]
    assert not re.search(r"(?m)^      anchors:(?! \[\]$)", spin)
    assert len(re.findall(r"(?m)^      anchors: \[\]$", spin)) == 42
    primary = {(int(frame), int(row)) for frame, row in
               re.findall(r"(?m)^    - frameIndex: (\d+)\n      rowIndex: (\d+)$", spin)}
    assert {frame for frame, row in primary if row == 0} == set(range(12))
    refs = [x["texture"] for x in original["directions"] if x is not None]
    refs += [f["sprite"]["texture"] for row in original["sequences"]["Attack"] for f in row]
    return {"source_commit": SOURCE, "purpose": "formal-primary-spear", "equipment_guid":
            item_guid, "spin_die_without_anchors": True,
            "textures": {key: source["textures"][key] for key in sorted(set(refs))},
            "frames": source["frames"], "options": [original]}


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo",type=Path)
    parser.add_argument("directory",type=Path)
    parser.add_argument("--legacy-pair",action="store_true",help="regenerate the original spear/heavy-shield-only manifest")
    parser.add_argument("--formal-spear",action="store_true",help="author primary spear contract with audited absence of SpinDie anchors")
    args=parser.parse_args()
    assert not (args.formal_spear and args.legacy_pair)
    result, name = (extract_primary_spear(args.repo,args.directory), "player-spear.json") if args.formal_spear \
        else (extract(args.repo,args.directory,args.legacy_pair), "weapons.json")
    (args.directory/name).write_bytes((json.dumps(result,indent=2,ensure_ascii=False)+"\n").encode("utf-8"))
