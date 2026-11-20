#!/usr/bin/env python3
"""Read ClickMoveTest's registered inventory prefab in the pinned Unity tree.

Write the layout data only to the private source-contract directory. This
describes the fresh panel geometry; does not export art or run Unity.
"""
import argparse
import hashlib
import json
from pathlib import Path

import yaml

from extract_clickmovetest_character import BASE
from extract_clickmovetest_character_layout import fixed_children, override
from extract_clickmovetest_pause import ATLAS, CONFIG, ROOT, SOURCE, docs, read, rect_in

PANEL = "Assets/GameRes/UI/Panels/UIInventory.prefab"
PARTS = "Assets/Prefabs/UI/MenuParts/Inventory/"
CURSOR = "Assets/Database/UI/ItemNavigationCursorStyle.asset"
RUNTIME = "Assets/Scripts/GameCore/Runtime/"


def extract(repo):
    dependencies = {}

    def raw(path):
        data = read(repo, path)
        dependencies[path] = hashlib.sha256(data).hexdigest()
        return data

    def model(path):
        return {i: row for i, (_, row) in docs(raw(path)).items()}

    def guid(path):
        return yaml.safe_load(raw(path + ".meta"))["guid"]

    def axes(xy):
        return [xy[a] for a in "xy"]

    def delta(rect):
        return axes(rect["m_SizeDelta"])

    def instance(records, child, prefab):
        pref = records[records[child]["m_PrefabInstance"]["fileID"]]
        assert pref["m_SourcePrefab"]["guid"] == guid(prefab)
        return pref

    ancestry = raw(ROOT).decode()
    assert "m_menu: 3\n    m_panelType:\n      m_assemblyQualifiedName: FantasyWord.GameCore.UIInventory, FantasyWord.GameCore" in ancestry
    action = raw(RUNTIME+"UI/Menus/UIGameMenuEntry.cs").decode()
    assert "OpenInventory" in action and "InventoryMenuContext.ViewCharacter" in action
    panel, base = map(model, [PANEL, BASE])
    bag, bag_slot, category, gear, gear_slot, stat = [model(PARTS+x+".prefab") for x in (
        "Bag","Bag item Slot","Category Entry","Equipment","Equipment Slot","Stat")]
    for name in ("UIInventory", "UIInventoryBag", "UIInventoryBagSlot", "UIInventoryBagCategory", "UIInventoryStats", "UIInventoryEquipment"):
        raw(RUNTIME+"UI/Menus/Inventory/"+name+".cs")
    raw(RUNTIME+"UI/UINavigationCursor.cs")
    cursor = model(CURSOR)[11400000]
    title = override(base[2915058637345498972],panel[6435120957728098511],2915058637345498972)
    screen = [0,0,1920,1080]
    base_instance = panel[6435120957728098511]
    assert base_instance["m_SourcePrefab"]["guid"] == guid(BASE)
    assert base_instance["m_Modification"]["m_AddedGameObjects"] == [{
        "targetCorrespondingSourceObject":{"fileID":625290108352659364,"guid":guid(BASE),"type":3},
        "insertIndex":-1,"addedObject":{"fileID":3354018164603445308}}]
    safe = rect_in(screen,base[625290108352659364])
    content = rect_in(safe,panel[3354018164603445308])
    stats_box, gear_bag = fixed_children(content,
        [delta(panel[k]) for k in (1330349971,2110767356)],panel[4678995037022189786],False)
    gear_root, bag_root = 9175780207568589869,4208455593649666625
    gear_instance = instance(panel,6435120958065787494,PARTS+"Equipment.prefab")
    bag_instance = instance(panel,7145335166831143774,PARTS+"Bag.prefab")
    gear_box, bag_box = fixed_children(gear_bag,
        [delta(override(gear[gear_root],gear_instance,gear_root)),delta(override(bag[bag_root],bag_instance,bag_root))],
        panel[2110767358],False)
    grid = rect_in(bag_box,bag[5068052902487346024])
    grid_layout = bag[5365552390978071264]
    assert (grid_layout["m_StartCorner"],grid_layout["m_StartAxis"],grid_layout["m_Constraint"]) == (3,0,0)
    assert grid_layout["m_ChildAlignment"]==0 and not any(grid_layout["m_Padding"].values())
    w,h = axes(grid_layout["m_CellSize"])
    sx,sy = axes(grid_layout["m_Spacing"])
    columns = round((grid[2]+sx)/(w+sx))
    rows = round((grid[3]+sy)/(h+sy))
    assert columns*(w+sx)-sx==grid[2] and rows*(h+sy)-sy==grid[3]
    children = bag[5068052902487346024]["m_Children"]
    assert len(children)==columns*rows==30
    grid_cells = []
    for i,child in enumerate(reversed(children)):
        child_id = child["fileID"]
        instance(bag,child_id,PARTS+"Bag item Slot.prefab")
        grid_cells.append({"source_object":str(child_id),"rect":[grid[0]+i%columns*(w+sx),grid[1]+i//columns*(h+sy),w,h]})

    category_box = rect_in(bag_box,bag[6537073050089606607])
    category_layout = bag[634076216715952572]
    assert category_layout["m_ChildControlWidth"]==category_layout["m_ChildForceExpandWidth"]==1
    assert category_layout["m_ChildControlHeight"]==0 and category_layout["m_ChildAlignment"]==4
    assert not any(category_layout["m_Padding"].values())
    category_root = 65271348870671771
    category_refs = bag[6537073050089606607]["m_Children"]
    specs = [override(category[category_root],instance(bag,ref["fileID"],PARTS+"Category Entry.prefab"),category_root)
             for ref in category_refs]
    cat_gap = category_layout["m_Spacing"]
    cat_w = (category_box[2]-(len(specs)-1)*cat_gap)/len(specs)
    config = model(CONFIG)[11400000]
    for field in ("m_itemCategoryTermsBinding","m_gameTerms"):
        assert not config[field]["m_keys"] and not config[field]["m_values"]
    get_term = raw(RUNTIME+"Game/GameConfig.Terms.cs").decode()
    assert 'shortName = "[INVALID_SHORTNAME]"' in get_term
    category_receiver = category[8528034034496258451]
    button = category[2618705507566220587]
    assert button["m_OnClick"]["m_PersistentCalls"]["m_Calls"][0]["m_MethodName"]=="SelectCategory"
    categories = [{"category":i,"term":"[INVALID_SHORTNAME]","icon":None,
                   "rect":[category_box[0]+i*(cat_w+cat_gap),category_box[1]+(category_box[3]-delta(k)[1])/2,cat_w,delta(k)[1]]}
                  for i,k in enumerate(specs)]
    gear_refs = gear[gear_root]["m_Children"]
    gear_instances = [instance(gear,ref["fileID"],PARTS+"Equipment Slot.prefab") for ref in gear_refs]
    g_visual = [override(gear_slot[4471496117887711044],pref,4471496117887711044)["m_equipmentType"]
                for pref in gear_instances]
    assert g_visual == list(range(5))
    def placeholder(pref):
        mods = pref["m_Modification"]["m_Modifications"]
        ref, = (m["objectReference"] for m in mods if m["target"]["fileID"]==4471496117245794029
                and m["propertyPath"]=="m_Sprite")
        return ref

    gear_cells = fixed_children(gear_box,[delta(gear_slot[4471496117887711047])]*len(gear_refs),gear[9175780207568589871],True)
    stats_children = panel[1330349971]["m_Children"]
    stat_root = 2782235941181438621
    stat_instances = [instance(panel,ref["fileID"],PARTS+"Stat.prefab") for ref in stats_children]
    stat_parts = [delta(stat[ref["fileID"]]) for ref in stat[stat_root]["m_Children"]]
    stat_group = stat[2782235941181438691]
    fit = stat[2782235941181438690]
    assert fit["m_HorizontalFit"]==fit["m_VerticalFit"]==2
    stat_size = [sum(w for w,h in stat_parts)+stat_group["m_Spacing"]*(len(stat_parts)-1),
                 max(h for w,h in stat_parts)]
    stat_boxes = fixed_children(stats_box,[stat_size]*len(stat_instances),panel[1330349973],True)
    summary = [{"row":box,"icon":parts[0],"label":parts[1],"value":parts[2]}
               for box in stat_boxes for parts in [fixed_children(box,stat_parts,stat_group,False)]]

    atlas_guid = guid(ATLAS)
    atlas_meta = yaml.safe_load(raw(ATLAS+".meta"))["TextureImporter"]
    assert atlas_meta["spritePixelsToUnits"]==16 and atlas_meta["textureSettings"]["filterMode"]==0
    backing = base[6380586684605756007]
    slot = bag_slot[5207285290398249215]
    assert backing["m_Type"]==2 and slot["m_Type"]==category[2801287862170884644]["m_Type"]==1
    assert button["m_Transition"]==2 and button["m_Navigation"]["m_Mode"]==-1
    sprite_refs = {"backing":backing["m_Sprite"],"slot":slot["m_Sprite"],"cursor":cursor["sprite"],
        "category_normal":category_receiver["m_unselectedSprite"],"category_active":category_receiver["m_selectedSprite"],
        **button["m_SpriteState"],
        **{f"gear_placeholder_{i}":placeholder(pref) for i,pref in enumerate(gear_instances)}}
    assert all(ref["guid"]==atlas_guid for ref in sprite_refs.values())
    atlas_rows = {s["internalID"]:{"rect":s["rect"],"border":s["border"]} for s in atlas_meta["spriteSheet"]["sprites"]}
    sprites = {k:{"id":str(ref["fileID"]),**atlas_rows[ref["fileID"]]} for k,ref in sprite_refs.items()}
    return {"schema":1,"source_commit":SOURCE,"pause_action":1,"registration":3,
        "title":title["m_text"],"content":content,"bag":bag_box,"grid_layout":grid_layout,
        "grid_cells":grid_cells,"category_strip":category_box,"categories":categories,
        "equipment_rects":gear_cells,"stat_rows":summary,"sprites":sprites,
        "cursor":{"size_offset":axes(cursor["sizeOffset"]),"position_offset":axes(cursor["positionOffset"]),
                  "color":cursor["color"]},"dependencies":dependencies}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo",required=True,type=Path)
    parser.add_argument("--out",required=True,type=Path)
    args = parser.parse_args()
    result = extract(args.repo)
    args.out.write_text(json.dumps(result,ensure_ascii=False,sort_keys=True,indent=2)+"\n")
