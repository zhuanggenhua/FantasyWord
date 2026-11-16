#!/usr/bin/env python3
"""Verify the private, authored Human Idle/Walk material inputs without copying assets."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import yaml

from extract_formal_human_animation import SOURCE, extract as animations, parse, read

ROOT = "Assets/GameData/EquipmentSystem/"
FRAME = ROOT + "FrameData/人类帧数据.asset"
APPEARANCE = ROOT + "Appearance/基础人形外观.asset"
BASE_PREFAB = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
SCENE = "Assets/Scenes/ClickMoveTest.unity"
PREFAB = "Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab"

def extract(repo, human, generated_uv, appearance_dir):
    animation = animations(repo, human)
    authored = read(repo, FRAME).decode().split("\n  - animationType: ")[1:]
    appearance = parse(read(repo, APPEARANCE))["MonoBehaviour"]
    prefab = read(repo, PREFAB).decode()
    base = read(repo, BASE_PREFAB).decode()
    scene = read(repo, SCENE).decode()
    base_guid = parse(read(repo, BASE_PREFAB + ".meta"))["guid"]
    player_guid = parse(read(repo, PREFAB + ".meta"))["guid"]
    frame_guid = parse(read(repo, FRAME + ".meta"))["guid"]
    appearance_guid = parse(read(repo, APPEARANCE + ".meta"))["guid"]
    assert f"m_SourcePrefab: {{fileID: 100100000, guid: {base_guid}," in prefab
    instance = [part for part in scene.split("--- !u!1001 &") if
                f"m_SourcePrefab: {{fileID: 100100000, guid: {player_guid}," in part]
    assert len(instance) == 1
    for inherited in ("frameData", "appearance", "initialEquipments"):
        assert "propertyPath: " + inherited not in prefab and "propertyPath: " + inherited not in instance[0]
    assert f"frameData: {{fileID: 11400000, guid: {frame_guid}," in base
    assert f"appearance: {{fileID: 11400000, guid: {appearance_guid}," in base
    assert "initialEquipments: []" in base
    assert not appearance["skinSrcColors"] and not appearance["skinDstColors"]
    assert all(appearance["faceAccessory" + d]["fileID"] == 0 for d in ("SE", "SW", "NE", "NW"))
    paths = subprocess.check_output(
        ["git", "-c", "core.quotepath=false", "-C", str(repo), "ls-tree", "-r", "--name-only", SOURCE],
        text=True).splitlines()
    textures = {}
    def verify_texture(path, local, guid, srgb, texture_type):
        meta = parse(read(repo, path + ".meta"))
        assert read(repo, path + ".meta") == local.with_name(local.name + ".meta").read_bytes()
        assert meta["guid"] == guid
        importer = meta["TextureImporter"]
        assert importer["textureSettings"]["filterMode"] == 0
        assert importer["mipmaps"]["sRGBTexture"] == srgb and importer["mipmaps"]["enableMipMap"] == 0
        assert importer["textureType"] == texture_type
        assert importer["textureSettings"]["wrapU"] == 1 and importer["textureSettings"]["wrapV"] == 1
        default = next(t for t in importer["platformSettings"] if t["buildTarget"] == "DefaultTexturePlatform")
        assert default["textureCompression"] == 0
        if texture_type == 8:
            assert importer["spriteMode"] == 1
        png = local.read_bytes()
        assert png[:8] == b"\x89PNG\r\n\x1a\n"
        sha = hashlib.sha256(png).hexdigest()
        source = read(repo, path)
        if source.startswith(b"version https://git-lfs.github.com/spec/v1\n"):
            assert f"oid sha256:{sha}\n" in source.decode() and f"size {len(png)}\n" in source.decode()
        else:
            assert png == source
        size = list(struct.unpack(">II", png[16:24]))
        textures[local.name] = {"size": size, "sha256": sha}
        return size

    actions = {}
    for name in ("Idle", "Walk"):
        main = f"Minifantasy_CreaturesHuman{name}.png"
        main_guid = parse((human / (main + ".meta")).read_bytes())["guid"]
        records = [block for block in authored if f"spritesheet: {{fileID: 2800000, guid: {main_guid}," in block]
        assert len(records) == 1
        # Only parse the selected animation, not tens of megabytes of unrelated per-pixel records.
        block = "- animationType: " + records[0]
        useful = ("    spritesheet:", "    frameSize:", "    framesPerRow:", "    rowCount:",
                  "    bodyUVMap:", "    headUVMap:", "    frames:", "    - frameIndex:",
                  "      rowIndex:", "      bodyRegions:", "      - part:",
                  "        spriteFacing:", "      leftEyeClosed:", "      rightEyeClosed:")
        selected = [line for line in block.splitlines() if line.startswith(useful)]
        record = yaml.safe_load("\n".join([block.splitlines()[0]] + [line[2:] for line in selected]))[0]
        assert record["frameSize"] == {"x": 32, "y": 32} and record["rowCount"] == 4
        assert animation["textures"][main]["size"] == [32 * record["framesPerRow"], 128]
        # The runtime animation key comes from animationType; the art PNG name alone is not authority.
        action_guid = record["animationType"]["guid"]
        types = [p for p in paths if p.startswith(ROOT) and p.endswith("/" + name + ".asset.meta")]
        definitions = [p[:-5] for p in types if parse(read(repo, p))["guid"] == action_guid]
        assert len(definitions) == 1, (name, types)
        assert name in parse(read(repo, definitions[0]))["MonoBehaviour"].values()
        result = {"main_sha256": animation["textures"][main]["sha256"], "frames": []}
        for part in ("Body", "Head"):
            file = main[:-4] + "_" + part + "UV.png"
            ref = record[part.lower() + "UVMap"]
            assert ref["fileID"] == 2800000
            actual = verify_texture(ROOT + "GeneratedUV/Human/" + file, generated_uv / file, ref["guid"], 0, 0)
            assert actual == animation["textures"][main]["size"]
            result[part.lower()] = file
        indexes = set()
        for row in record["frames"]:
            x, y = row["frameIndex"], row["rowIndex"]
            assert (x,y) not in indexes
            indexes.add((x,y))
            regions = {}
            for region in row["bodyRegions"]:
                semantic = {0:"head", 1:"torso"}.get(region["part"])
                if semantic is not None and semantic not in regions:
                    regions[semantic] = {"sprite_facing": region["spriteFacing"]}
            result["frames"].append({"frame_index": x, "row_index": y, "body_regions": regions,
                                     "left_eye_closed": bool(row["leftEyeClosed"]),
                                     "right_eye_closed": bool(row["rightEyeClosed"])})
        expected = {(r["rect"][0]//32, (128-r["rect"][1]-32)//32) for group in animation["actions"][name]["directions"] for r in group}
        assert indexes == expected
        actions[name] = result

    look = {}
    for name in ["hair"+d for d in ("SE","SW","NE","NW")] + ["beard"+d for d in ("SE","SW","NE","NW")] + ["eyeDecorationEast","eyeDecorationWest"]:
        ref = appearance[name]
        assert ref["fileID"] == 21300000
        local = appearance_dir / (name + ".png")
        if name.startswith("hair"):
            filename = "hair" + str(("SE","SW","NE","NW").index(name[4:])+1)
        elif name.startswith("beard"):
            filename = "chin_white" + str(("SE","SW","NE","NW").index(name[5:])+1)
        else:
            filename = "黄色刀疤" + ("1" if name.endswith("East") else "2")
        original = "Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/" + filename + ".png"
        verify_texture(original, local, ref["guid"], 1, 8)
        look[name] = local.name
    for eye in ("leftEyeColor","rightEyeColor"):
        look[eye] = [appearance[eye][k] for k in "rgba"]
    return {"schema": 1, "source_commit": SOURCE, "textures": textures, "actions": actions, "appearance": look}

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "human", "generated-uv", "appearance-dir", "output"):
        p.add_argument("--" + name, type=Path, required=True)
    a = p.parse_args()
    data = extract(a.repo, a.human, a.generated_uv, a.appearance_dir)
    a.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("Verified authored Human Idle/Walk material inputs.")
