#!/usr/bin/env python3
"""核实锁定训练假人的运行时动画归属，复用 Human 提取器输出私有合同。"""
import argparse
import hashlib
import json
import re
from pathlib import Path
import yaml
from extract_formal_human_animation import SOURCE, extract, read

PREFIX = "Assets/Prefabs/Entities/Characters/"

def documents(raw):
    text = re.sub(r"^%.*\n", "", raw.decode(), flags=re.M)
    text = re.sub(r"^--- !u!\d+ &[-\d]+(?: stripped)?", "---", text, flags=re.M)
    return list(yaml.safe_load_all(text))

def extract_target(repo, textures):
    sources = {}
    def source(path):
        raw = read(repo, path)
        sources[path] = hashlib.sha256(raw).hexdigest()
        return raw
    trainer = documents(source(PREFIX+"Enemies/测试-训练假人.prefab"))
    instance = trainer[0]["PrefabInstance"]
    assert instance["m_SourcePrefab"]["guid"] == "5865f29bb760d4342b20bf32a1e06ca8"
    changes = instance["m_Modification"]
    assert not changes["m_RemovedComponents"] and not changes["m_RemovedGameObjects"]
    mods = changes["m_Modifications"]
    # 静态旧库只含四帧 Idle/Run/Hit；运行时会由继承方向驱动替换，不能直接迁移成 Dmg。
    lib = next(m for m in mods if m["propertyPath"] == "m_SpriteLibraryAsset")
    assert lib["objectReference"]["guid"] == "e98f566e251e635449fc9d663904607b"
    actor = documents(source(PREFIX+"0_CharacterActor_Base.prefab"))
    actor_instance = next(d["PrefabInstance"] for d in actor if "PrefabInstance" in d)
    assert actor_instance["m_SourcePrefab"]["guid"] == "35b65aa833459fb48a5da6b625c71835"
    controller_override = next(m for m in actor_instance["m_Modification"]["m_Modifications"] if m["target"]["fileID"] == 8844624622341381040 and m["propertyPath"] == "m_Controller")
    assert controller_override["objectReference"]["guid"] == "0be334fca6154804592795b046bebf5c"
    def component(name):
        matches = [d["MonoBehaviour"] for d in actor if "MonoBehaviour" in d and (d["MonoBehaviour"].get("m_EditorClassIdentifier") or "").endswith("."+name)]
        assert len(matches) == 1 and matches[0]["m_Enabled"] == 1
        return matches[0]
    driver = component("CharacterActionAnimatorDriver")
    assert (driver["defaultAnimationKey"],driver["movementAnimationKey"],driver["damageAnimationKey"]) == ("Idle","Walk","Dmg")
    direction = component("DirectionalSpriteLibraryDriver")
    expected = ["62c4a52ab213438419c93cc2d8427623","0602b79d46e41504a8117d1fdcc863b2","aaefe509e84579b4782b521a1d156e71","9ea72d0165623924d891e3222ac25d48"]
    assert [direction["defaultAnimationLibraries"][k]["guid"] for k in ("southEast","southWest","northEast","northWest")] == expected
    for d,guid in zip(("SE","SW","NE","NW"),expected):
        meta = yaml.safe_load(source(f"Assets/GameData/EquipmentSystem/Animations/SpriteLibraries/人类_{d}动画精灵库.asset.meta"))
        assert meta["guid"] == guid
    equipment = component("EquipmentRenderer")
    assert equipment["frameData"]["guid"] == "720d2b3b0c58d5b4295a6468bd84a86c"
    assert equipment["appearance"]["guid"] == "a1ff30d38f2dfa346a3c8920b6183736"
    assert equipment["initialEquipments"] == []
    # 训练假人无这三个继承组件/其参数的覆盖；不得默默采用类似玩家配置。
    forbidden = ("defaultAnimation", "movementAnimation", "damageAnimation", "characterAnimator", "frameData", "appearance", "defaultAnimationLibraries")
    assert not any(m["propertyPath"].startswith(forbidden) for m in mods)
    body = documents(source(PREFIX+"0_Character_Base.prefab"))
    transform = next(d["Transform"] for d in body if "Transform" in d and d["Transform"].get("m_GameObject",{}).get("fileID") == 4877509768872866472)
    assert transform["m_LocalPosition"] == dict(x=0,y=0,z=0)
    assert transform["m_LocalScale"] == dict(x=1,y=1,z=1)
    runtime = source("Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem/Runtime/DirectionalSpriteLibraryDriver.cs").decode()
    assert "SetAnimationLibraries(defaultAnimationLibraries, false)" in runtime
    assert "spriteLibrary.spriteLibraryAsset = asset;" in runtime
    result = extract(repo, textures, include_damage=True)
    result["source_sha256"].update(sources)
    result["training_target"] = {"prefab_guid":"dca23ea6afacc0647bfd10c5cefa4099", "body_local_position":[0,0], "runtime_libraries":expected}
    return result

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo",type=Path,required=True)
    parser.add_argument("--textures",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    result=extract_target(args.repo,args.textures)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("PASS 训练假人继承、运行时方向库、Idle/Walk/Dmg 原始图集合同")
