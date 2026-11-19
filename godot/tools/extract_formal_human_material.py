#!/usr/bin/env python3
"""核实私有 Human 或 ClickMoveTest 原训练假人的材质输入，不复制原始资产。"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import yaml

from extract_formal_human_animation import SOURCE, extract as animations, parse, read
from extract_training_target_animation import documents, extract_target

ROOT = "Assets/GameData/EquipmentSystem/"
FRAME = ROOT + "FrameData/人类帧数据.asset"
APPEARANCE = ROOT + "Appearance/基础人形外观.asset"
BASE_PREFAB = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
SCENE = "Assets/Scenes/ClickMoveTest.unity"
PREFAB = "Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab"
GAME_CONFIG = "Assets/GameData/GameCore/GameConfig.asset"
CONFIG_GUID = "b669f9c81be34b47bf3d083609477ab5"
BASE_ACTOR = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
TRAINER = "Assets/Prefabs/Entities/Characters/Enemies/测试-训练假人.prefab"

def extract(repo, human, generated_uv, appearance_dir, include_damage=False, training_target=False, include_attack=False, include_death=False):
    animation = extract_target(repo, human, include_death=True, include_attack=include_attack) if training_target else animations(repo, human, include_damage, include_attack=include_attack, include_death=include_death)
    authored = read(repo, FRAME).decode().split("\n  - animationType: ")[1:]
    appearance = parse(read(repo, APPEARANCE))["MonoBehaviour"]
    prefab_path = TRAINER if training_target else PREFAB
    prefab = read(repo, prefab_path).decode()
    base = read(repo, BASE_PREFAB).decode()
    scene = read(repo, SCENE).decode()
    base_guid = parse(read(repo, BASE_PREFAB + ".meta"))["guid"]
    prefab_guid = parse(read(repo, prefab_path + ".meta"))["guid"]
    frame_guid = parse(read(repo, FRAME + ".meta"))["guid"]
    appearance_guid = parse(read(repo, APPEARANCE + ".meta"))["guid"]
    assert f"m_SourcePrefab: {{fileID: 100100000, guid: {base_guid}," in prefab
    instances = [part for part in scene.split("--- !u!1001 &") if
                 f"m_SourcePrefab: {{fileID: 100100000, guid: {prefab_guid}," in part]
    if training_target:
        assert prefab_guid == animation["training_target"]["prefab_guid"]
        # ClickMoveTest 另外保留了停用的转向测试假人；只核实活动实例。
        instances = [part for part in instances if "propertyPath: m_IsActive\n      value: 0" not in part]
    assert len(instances) == 1
    inherited_fields = ("frameData", "appearance", "initialEquipments")
    if training_target:
        inherited_fields += ("overrideShader", "m_Materials", "m_Enabled")
    for inherited in inherited_fields:
        assert "propertyPath: " + inherited not in prefab and "propertyPath: " + inherited not in instances[0]
    if training_target:
        actor_base = documents(read(repo, BASE_PREFAB))
        renderer = next(d["MonoBehaviour"] for d in actor_base if (d.get("MonoBehaviour", {}).get("m_EditorClassIdentifier") or "").endswith(".EquipmentRenderer"))
        assert renderer["m_Enabled"] == 1 and renderer["overrideShader"]["fileID"] == 0
        assert renderer["frameData"]["guid"] == frame_guid and renderer["appearance"]["guid"] == appearance_guid
        assert renderer["initialEquipments"] == []
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
    for name in animation["actions"]:
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
        spin_die = name == "SpinDie"
        assert record["frameSize"] == {"x": 32, "y": 32} and record["rowCount"] == (1 if spin_die else 4)
        height = 32 * record["rowCount"]
        assert animation["textures"][main]["size"] == [32 * record["framesPerRow"], height]
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
        directions = animation["actions"][name]["directions"]
        expected = {(r["rect"][0]//32, (height-r["rect"][1]-32)//32) for group in directions for r in group}
        if spin_die:
            # SyncFromSprite 按实际 32 像素高的纹理求行号。四库引用同一行；
            # 其余 30 条遗留作者记录不可采样，不能误判最后两帧缺少原数据。
            assert all(direction == directions[0] for direction in directions)
            assert expected == {(x, 0) for x in range(12)}
            assert indexes == expected | {(x, y) for x in range(10) for y in (1, 2, 3)}
            result["frames"] = [frame for frame in result["frames"] if frame["row_index"] == 0]
        else:
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
    result = {"schema": 1, "source_commit": SOURCE, "textures": textures, "actions": actions, "appearance": look}
    if training_target:
        result["training_target"] = animation["training_target"]
    elif include_death:
        # 仅核实 ClickMoveTest 已启用的原 GameManager 与主角。空动作不是菜单。
        manager = next(s for s in scene.split("--- !u!114 &") if s.startswith("1468008383\n"))
        assert "m_Enabled: 1" in manager and "FantasyWord.GameCore::FantasyWord.GameCore.GameManager" in manager
        assert f"m_config: {{fileID: 11400000, guid: {CONFIG_GUID}, type: 2}}" in manager
        assert parse(read(repo, GAME_CONFIG+".meta"))["guid"] == CONFIG_GUID
        config_raw = read(repo, GAME_CONFIG)
        config = parse(config_raw)["MonoBehaviour"]
        assert config["m_toExecuteOnPlayerDeath"] == {"rid":-2}
        assert config["references"]["RefIds"] == [{"rid":-2,"type":{"class":None,"ns":None,"asm":None}}]
        assert "propertyPath: deathAnimationKey" not in prefab and "propertyPath: deathAnimationKey" not in instances[0]
        driver = next(d["MonoBehaviour"] for d in documents(read(repo, BASE_ACTOR))
                      if (d.get("MonoBehaviour", {}).get("m_EditorClassIdentifier") or "").endswith(".CharacterActionAnimatorDriver"))
        assert driver["m_Enabled"] == 1 and driver["deathAnimationKey"] == "SpinDie"
        assert instances[0].startswith("735002000000000001\n")
        assert "m_primaryPlayerCharacter: {fileID: 735002000000000004}" in scene
        actor = next(s for s in scene.split("--- !u!114 &") if s.startswith("735002000000000004 stripped\n"))
        assert "m_PrefabInstance: {fileID: 735002000000000001}" in actor
        assert f"m_CorrespondingSourceObject: {{fileID: 8122841227683649615, guid: {prefab_guid}," in actor
        result["primary_death"] = {"config_guid":CONFIG_GUID,"action_rid":-2,"animation_key":"SpinDie",
            "actor_file_id":"735002000000000004","config_sha256":hashlib.sha256(config_raw).hexdigest()}
    return result

if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "human", "generated-uv", "appearance-dir", "output"):
        p.add_argument("--" + name, type=Path, required=True)
    p.add_argument("--include-damage", action="store_true", help="同时核实 Dmg 的原帧数据与生成 UV")
    p.add_argument("--training-target", action="store_true", help="核实活动训练假人的 Idle/Walk/Dmg/SpinDie")
    p.add_argument("--include-attack", action="store_true", help="同时核实普攻原帧与两张 UV")
    p.add_argument("--include-death", action="store_true", help="核实原 ClickMoveTest 主角的 SpinDie 与空死亡动作")
    a = p.parse_args()
    assert not (a.training_target and a.include_death), "主角死亡选项不适用于训练假人"
    data = extract(a.repo, a.human, a.generated_uv, a.appearance_dir, a.include_damage, a.training_target, a.include_attack, a.include_death)
    a.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("Human 私有材质输入已核实：" + ", ".join(data["actions"]))
