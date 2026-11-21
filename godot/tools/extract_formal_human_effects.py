#!/usr/bin/env python3
"""Export locked original primary human foot/outline markers; keep output private."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from extract_formal_human_animation import SOURCE, extract, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
SHADER = "Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem/"
FRAME = ROOT + "FrameData/人类帧数据.asset"


def build(repo, textures):
    actor = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
    mat = SHADER + "Shaders/EquipmentRender.mat"
    raw = read(repo, FRAME)
    ground = int(re.search(r"^  groundPixelY: (\d+)$", raw.decode(), re.M)[1])
    assert ground == 18
    props = parse(read(repo, mat))["Material"]["m_SavedProperties"]
    floats = {k: v for row in props["m_Floats"] for k, v in row.items()}
    colors = {k: [v[c] for c in "rgba"] for row in props["m_Colors"] for k, v in row.items()}
    assert [floats[k] for k in ("_DefaultOutlineEnabled", "_ExtraOutlineEnabled", "_ShadowEnabled",
                                "_ShadowBaseY", "_ShadowCenterX")] == [1, 0, 1, .25, .5]
    assert colors["_HitOutlineColor"] == [.7059, .0353, .0353, 1]
    assert colors["_ExtraOutlineColor"] == [1, 1, 1, 1]
    assert colors["_ShadowColor"] == [0, 0, 0, .6]
    assert "overrideShader: {fileID: 0}" in read(repo, actor).decode()
    renderer = read(repo, SHADER + "Runtime/EquipmentRenderer.cs").decode()
    assert "new Material(shader)" in renderer and "EquipmentUV" in renderer
    shader = read(repo, SHADER + "Shaders/EquipmentUV.shader").decode()
    for key in ("_ShadowBaseY", "_ShadowCenterX", "_ShadowColor", "_HitOutlineColor", "_ExtraOutlineColor", "_ExtraOutlineEnabled"):
        value = re.search(r"^\s*(?:\[[^\]]+\]\s*)?" + key + r" .* = ([^\n]+)$", shader, re.M)[1]
        assert (list(map(float, value.strip("()").split(","))) if key in colors else float(value)) == (colors[key] if key in colors else floats[key])
    assert parse(read(repo, FRAME + ".meta"))["guid"] in read(repo, actor).decode()
    catalog = extract(repo, textures, include_damage=True, include_attack=True, include_death=True)
    blocks = raw.decode().split("\n  - animationType: ")[1:]
    actions = {}
    for action, spec in catalog["actions"].items():
        guid = parse(read(repo, ROOT + f"AnimationType/{action}.asset.meta"))["guid"]
        block, = (b for b in blocks if guid in b.splitlines()[0])
        name, = {frame["texture"] for direction in spec["directions"] for frame in direction}
        atlas_guid = parse((textures / (name + ".meta")).read_bytes())["guid"]
        assert f"spritesheet: {{fileID: 2800000, guid: {atlas_guid}," in block
        assert "    frameSize: {x: 32, y: 32}\n" in block
        wx, wy = catalog["textures"][name]["size"]
        cells = {(int(rect[0]) // 32, (wy - int(rect[1]) - 32) // 32)
                 for direction in spec["directions"] for frame in direction for rect in [frame["rect"]]}
        rows = {}
        for match in re.finditer(r"^    - frameIndex: (\d+)\n      rowIndex: (\d+)\n(.*?)(?=^    - frameIndex: |\Z)", block, re.M | re.S):
            x, y, record = match.groups()
            key = (int(x), int(y))
            if key not in cells:
                continue
            mask = re.search(r"^      limbMask:\n(.*?)^      leftEyeClosed:", record, re.M | re.S)[1]
            feet = parse(("limbMask:\n" + mask).encode())["limbMask"]
            hit = int(re.search(r"^      hitOutlineFrame: ([01])$", record, re.M)[1])
            assert key not in rows
            rows[key] = [*key, feet["leftFoot"], feet["rightFoot"], hit]
        assert rows.keys() == cells
        actions[action] = {"size": [wx, wy], "frames": [rows[k] for k in sorted(rows)]}
    assert {k: len(v["frames"]) for k, v in actions.items()} == {
        "Idle": 64, "Walk": 16, "Dmg": 16, "Attack": 16, "SpinDie": 12,
    }
    return {"source": SOURCE, "frame_sha256": hashlib.sha256(raw).hexdigest(),
            "material_sha256": hashlib.sha256(read(repo, mat)).hexdigest(),
            "ground_pixel_y": ground, "actions": actions}


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("repo", type=Path)
    cli.add_argument("textures", type=Path)
    cli.add_argument("output", type=Path)
    args = cli.parse_args()
    data = (json.dumps(build(args.repo, args.textures), indent=2) + "\n").encode()
    args.output.write_bytes(data)
    print("正式主角原帧轮廓/阴影合同 SHA-256:", hashlib.sha256(data).hexdigest())
