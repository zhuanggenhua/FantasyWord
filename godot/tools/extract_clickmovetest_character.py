#!/usr/bin/env python3
"""Lock UICharacter's actual stat receivers and fresh actor provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

import yaml

from extract_clickmovetest_pause import SCENE, ROOT, SOURCE, docs, read

PANEL = "Assets/GameRes/UI/Panels/UICharacter.prefab"
BASE = "Assets/Prefabs/UI/MenuParts/Frames/Base Menu.prefab"
ROW = "Assets/Prefabs/UI/MenuParts/Stats/Stat_With_Buttons.prefab"
HERO = "Assets/Prefabs/Entities/Characters/Heroes/玩家角色.prefab"
SHEET = "Assets/Database/Characters/Heroes/玩家角色配置.asset"
ACTOR = "Assets/Prefabs/Entities/Characters/0_CharacterActor_Base.prefab"
PANEL_SHA = "8056f45e7691c4b270e039ee9fae88146e6f8e3b46618439d3d5a99c88a5d997"


def extract(repo):
    deps = {}

    def load(path):
        raw = read(repo, path)
        deps[path] = hashlib.sha256(raw).hexdigest()
        return raw

    def guid(path):
        return yaml.safe_load(load(path+".meta"))["guid"]

    ui = docs(load(ROOT))
    registration, = [f for _, f in ui.values() if "m_registeredMenuPanels" in f]
    reg, = [r for r in registration["m_registeredMenuPanels"] if r["m_menu"]==1]
    assert reg["m_panelType"]["m_assemblyQualifiedName"].split(",")[0].endswith(".UICharacter")
    panel = docs(load(PANEL))
    assert deps[PANEL] == PANEL_SHA
    ctl = panel[1969439460][1]
    base = panel[1257309155729834875][1]
    assert base["m_SourcePrefab"]["guid"] == guid(BASE)
    expected = [set(ctl[k]) for k in ("m_class","m_level","m_experience","m_skillPoints","m_currency","m_applyButtonText")]
    assert all(k=={"fileID"} for k in expected)
    fields = {k: str(ctl[k]["fileID"]) for k in ("m_class","m_level","m_experience","m_skillPoints","m_currency","m_applyButtonText")}
    assert all(int(i) in panel for i in fields.values())
    template = docs(load(ROW))
    row_guid = guid(ROW)
    runtime_id = 104031430085134022
    template_record = template[runtime_id][1]
    assert all(template_record[k]["fileID"] in template for k in ("m_decreaseButton","m_increaseButton","m_value"))
    rows = []
    for ref in ctl["m_stats"]:
        id_ = ref["fileID"]
        stripped = panel[id_][1]
        assert stripped["m_CorrespondingSourceObject"]["fileID"]==runtime_id
        assert stripped["m_CorrespondingSourceObject"]["guid"]==row_guid
        instance = panel[stripped["m_PrefabInstance"]["fileID"]][1]
        assert instance["m_SourcePrefab"]["guid"]==row_guid
        mods = instance["m_Modification"]["m_Modifications"]
        stat = [int(m["value"]) for m in mods if m["target"]["fileID"]==runtime_id and m["propertyPath"]=="m_stat"]
        assert len(stat)<=1
        rows.append({"receiver":str(id_),"stat":stat[0] if stat else template_record["m_stat"]})
    assert len(rows)==8 and set(r["stat"] for r in rows)==set(range(8))

    scene = load(SCENE).decode()
    hero_guid, sheet_guid, actor_guid = guid(HERO),guid(SHEET),guid(ACTOR)
    assert "m_primaryPlayerCharacter: {fileID: 735002000000000004}" in scene
    player_instance = scene.split("--- !u!1001 &735002000000000001\n",1)[1].split("\n--- ",1)[0]
    assert f"m_SourcePrefab: {{fileID: 100100000, guid: {hero_guid}, type: 3}}" in player_instance
    assert all("propertyPath: "+p not in player_instance for p in ("m_sheet","m_level","m_usedPoints","m_experience"))
    hero = docs(load(HERO))
    instance, = [f for kind,f in hero.values() if kind=="PrefabInstance" and f["m_SourcePrefab"]["guid"]==actor_guid]
    mod, = [m for m in instance["m_Modification"]["m_Modifications"] if m["propertyPath"]=="m_sheet"]
    assert mod["objectReference"]["guid"]==sheet_guid
    actor=docs(load(ACTOR))
    assert actor[mod["target"]["fileID"]][1]["m_level"]==1
    sheet=docs(load(SHEET))[11400000][1]
    stats=list(struct.unpack("<9i",bytes.fromhex(sheet["m_baseStats"]["m_values"])))
    assert sheet["m_useLevelScaledStats"]==0 and sheet["m_pointsPerLevel"]==5
    assert not sheet["m_displayName"] and sheet["m_experience"]["m_initialValue"]==0
    assert stats==[100,40,10,6,6,4,8,4,100]
    scripts = "Assets/Scripts/GameCore/Runtime/"
    for path in ("UI/Menus/Character/UICharacter.cs", "UI/Menus/Character/UICharacterStat.cs",
                 "Miscellaneous/DisplayNameUtils.cs", "Scaling/LevelScaledInteger.cs",
                 "Scaling/LevelScaledValue.cs","Entities/Characters/CharacterBase.Resources.cs",
                 "Entities/Characters/CharacterActor.cs","Game/Systems/InventorySystem.cs"):
        load(scripts+path)
    return {"schema":1,"source_commit":SOURCE,"dependencies":deps,"fields":fields,"rows":rows,
            "registration":1,"pause_action":5,"actor_file_id":"735002000000000004","sheet_guid":sheet_guid,
            "fresh":{"display_name":sheet["m_Name"],
                     "level":1,"minimum_level":1,"points_per_level":sheet["m_pointsPerLevel"],
                     "experience":0,"next_level_experience":0,"used_points":0,"base_stats":stats}}


if __name__=="__main__":
    cli=argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--repo",type=Path,required=True)
    cli.add_argument("--output",type=Path,required=True)
    a=cli.parse_args()
    result=extract(a.repo)
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("PASS original UICharacter eight stat receivers and actual fresh player sheet.")
