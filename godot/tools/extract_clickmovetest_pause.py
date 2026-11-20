#!/usr/bin/env python3
"""锁定原 ClickMoveTest 菜单输入、动态加载、布局、图集和字体；合同只在私有目录输出。"""
import argparse
import hashlib
import json
from pathlib import Path
import re

import yaml
from extract_formal_human_animation import SOURCE, read

SCENE = "Assets/Scenes/ClickMoveTest.unity"
ROOT = "Assets/Prefabs/UI/User Interface.prefab"
PANEL = "Assets/GameRes/UI/Panels/UIGameMenu.prefab"
ENTRY = "Assets/Prefabs/UI/MenuParts/SystemMenu/Game Menu Entry.prefab"
ATLAS = "Assets/Sprites/ThirdParty/PaperHatLizard/SPS_GUI.png"
FONT = "Assets/Fonts/RPGSystem SDF.asset"
INPUT = "Assets/InputSystem_Actions.inputactions"
FONT_SHADER = "Assets/TextMesh Pro/Shaders/TMP_SDF.shader"
FONT_INCLUDE = "Assets/TextMesh Pro/Shaders/TMPro.cginc"
HEADER = re.compile(r"^--- !u!\d+ &(-?\d+)(?: stripped)?\s*$", re.M)
CONFIG = "Assets/GameData/GameCore/GameConfig.asset"
ENTRY_SCRIPT = "Assets/Scripts/GameCore/Runtime/UI/Menus/UIGameMenuEntry.cs"
PAUSE_COMPONENT = 2443491108180093687
PAUSE_SHA = "59cac49c9686dcb3bd7efe6362dbc6ce7541664c51e66feec8dfe0e7503d217f"


def docs(raw):
    parts = HEADER.split(raw.decode())
    result = {}
    for i in range(1, len(parts), 2):
        record = yaml.safe_load(parts[i + 1])
        assert isinstance(record, dict) and len(record) == 1
        result[int(parts[i])] = next(iter(record.items()))
    return result


def by_field(records, field):
    return [value for _, value in records.values() if field in value]


def refs(value, guid):
    """收集 YAML 里有指定 GUID 的所有 fileID，处理作者的预制体覆盖引用。"""
    if isinstance(value, dict):
        if value.get("guid") == guid and isinstance(value.get("fileID"), int):
            yield value["fileID"]
        for item in value.values():
            yield from refs(item, guid)
    elif isinstance(value, list):
        for item in value:
            yield from refs(item, guid)


def rect_in(parent, fields):
    """Reference Canvas, returning [left, top, width, height] in Godot order."""
    assert fields["m_LocalScale"] == dict(x=1,y=1,z=1)
    assert fields["m_LocalRotation"] == dict(x=0,y=0,z=0,w=1)
    lo, hi = fields["m_AnchorMin"], fields["m_AnchorMax"]
    delta, pivot = fields["m_SizeDelta"], fields["m_Pivot"]
    pos = fields["m_AnchoredPosition"]
    x, y, w, h = parent
    sx = w * (hi["x"] - lo["x"]) + delta["x"]
    sy = h * (hi["y"] - lo["y"]) + delta["y"]
    px = lo["x"] + (hi["x"] - lo["x"]) * pivot["x"]
    py = lo["y"] + (hi["y"] - lo["y"]) * pivot["y"]
    return [x + w * px + pos["x"] - sx * pivot["x"],
            y + h * (1 - py) - pos["y"] - sy * (1 - pivot["y"]), sx, sy]


def extract_entry_layout(panel, base, prefab_guid, atlas_guid, config, script, script_guid, registration):
    root_id = 7569937386360487286
    root_go = 7569937386360487287
    logic_id = 7569937386360487285
    button_id = 7569937386360487284
    icon_id = 7569937387984739770
    icon_rect = 7569937387984739771
    label_id = 7569937386815868997
    label_rect = 7569937386815868998
    logic = base[logic_id][1]
    button = base[button_id][1]
    assert logic["m_Script"]["guid"] == script_guid
    assert logic["m_button"]["fileID"] == button_id and logic["m_text"]["fileID"] == label_id
    assert button["m_Transition"] == 1 and button["m_TargetGraphic"]["fileID"] == icon_id
    assert base[icon_id][1]["m_Type"] == 0 and not base[icon_id][1]["m_PreserveAspect"]
    assert base[icon_id][1]["m_Color"] == dict(r=1,g=1,b=1,a=1)
    enum, = re.findall(r'enum EGameMenuAction\s*\{([^}]+)\}', script)
    actions = re.sub(r'\[[^\]]+\]', '', enum)
    actions = [name.strip() for name in actions.split(",") if name.strip()]
    assert actions == ["None","OpenInventory","OpenJournal","OpenSaveMenu","OpenAbilities",
                       "OpenCharacter","OpenCraft","OpenSettings","GoToMainMenu"]
    assert re.search(r'm_action == EGameMenuAction.OpenCraft && GameManager.Config.onTheGoCraftingStation == null\)\s*\{\s*gameObject.SetActive\(false\);',script)
    craft = bool(config["m_onTheGoCraftingStation"]["fileID"])

    container = panel[2795412860309662026][1]
    holder = panel[container["m_Father"]["fileID"]][1]
    reference = [0, 0, 1920, 1080]
    root_bounds = rect_in(reference, holder)
    assert root_bounds == reference
    children = [child["fileID"] for child in container["m_Children"]]
    frame_id, *stripped_entries = children
    frame = panel[frame_id][1]
    assert frame["m_Father"]["fileID"] == 2795412860309662026
    assert panel[3326058719984672510][1]["m_IgnoreLayout"] == 1
    group = panel[5156917214967545894][1]
    fitter = panel[8232519872658458252][1]
    assert group["m_Enabled"] == fitter["m_Enabled"] == 1
    assert group["m_ChildAlignment"] == 4 and group["m_Spacing"] == 0 and not any(group["m_Padding"].values())
    assert all(group[key] == 0 for key in ("m_ChildControlWidth","m_ChildControlHeight",
                                           "m_ChildForceExpandWidth","m_ChildForceExpandHeight",
                                           "m_ChildScaleWidth","m_ChildScaleHeight"))
    assert fitter["m_HorizontalFit"] == fitter["m_VerticalFit"] == 2
    registrations = {row["prefab_instance"] for row in registration}
    rows = []
    for order, child in enumerate(stripped_entries, 1):
        stripped = panel[child][1]
        assert stripped["m_CorrespondingSourceObject"]["fileID"] == root_id
        iid = stripped["m_PrefabInstance"]["fileID"]
        instance = panel[iid][1]
        assert instance["m_SourcePrefab"]["guid"] == prefab_guid
        assert instance["m_Modification"]["m_TransformParent"]["fileID"] == 2795412860309662026
        mods = instance["m_Modification"]["m_Modifications"]
        by_prop = {}
        for mod in mods:
            assert mod["target"]["guid"] == prefab_guid
            key = (mod["target"]["fileID"], mod["propertyPath"])
            assert key not in by_prop
            by_prop[key] = mod
        def value(target, key, default=None):
            item = by_prop.get((target,key))
            return default if item is None else item["value"]
        assert value(root_id, "m_RootOrder") == order
        action = value(logic_id, "m_action", logic["m_action"])
        label = value(label_id, "m_text", base[label_id][1]["m_text"])
        shown = bool(value(root_go, "m_IsActive", base[root_go][1]["m_IsActive"]))
        icon = by_prop[(icon_id,"m_Sprite")]["objectReference"]
        assert icon["guid"] == atlas_guid and icon["fileID"]
        dimensions = [value(root_id, "m_SizeDelta."+axis, base[root_id][1]["m_SizeDelta"][axis]) for axis in ("x","y")]
        assert dimensions == [80,80]
        for part in ("m_LocalScale", "m_LocalRotation", "m_Pivot"):
            for axis, default in base[root_id][1][part].items():
                assert value(root_id, part+"."+axis, default) == default
        rows.append(dict(transform_id=str(child), prefab_instance=str(iid), label=label, action=action,
                         action_name=actions[action], sprite_id=str(icon["fileID"]), authored_active=shown,
                         visible=shown and (actions[action] != "OpenCraft" or craft), registered=str(iid) in registrations))
    assert [row["action"] for row in rows] == [5,1,4,2,6,3,7,8]
    assert sum(row["registered"] for row in rows) == len(registrations)
    width, height = dimensions
    container = dict(container, m_SizeDelta=dict(x=width, y=height*sum(row["visible"] for row in rows)))
    body_bounds = rect_in(root_bounds,container)
    position = 0
    for row in rows:
        if not row["visible"]:
            continue
        bounds = [body_bounds[0], body_bounds[1] + position * height, width, height]
        row.update(rect=bounds,icon_rect=rect_in(bounds,base[icon_rect][1]),label_rect=rect_in(bounds,base[label_rect][1]))
        position += 1
    return dict(body_rect=body_bounds,frame_rect=rect_in(body_bounds,frame),rows=rows,tints=button["m_Colors"],
                craft_available=craft, label_size=base[label_id][1]["m_fontSize"])


def extract_default_footer(panel, root, load, single_line):
    manager = "Assets/Prefabs/UI/UI Controller Button Manager.prefab"
    manager_guid = yaml.safe_load(load(manager+".meta"))["guid"]
    instance, = [f for kind,f in root.values() if kind=="PrefabInstance"
                  and f.get("m_SourcePrefab",{}).get("guid")==manager_guid]
    mods = instance["m_Modification"]
    assert not any(m["target"]["fileID"]==4477607149501167889 for m in mods["m_Modifications"])
    assert not mods["m_RemovedComponents"] and not mods["m_RemovedGameObjects"]
    prefab = docs(load(manager))
    controller = prefab[4477607149501167889][1]
    assert prefab[4477607149501167891][1]["m_IsActive"] == controller["m_Enabled"] == 1
    assert controller["m_buttonPromptsVisible"] == 0
    scripts = "Assets/Scripts/GameCore/Runtime/UI/"
    load(scripts+"UIControllerButtonManager.cs")
    load(scripts+"UIControllerButton.cs")
    button_guid = yaml.safe_load(load(scripts+"UIControllerButton.cs.meta"))["guid"]

    parent_id = 1205093984960525369
    holder = panel[parent_id][1]
    assert panel[holder["m_GameObject"]["fileID"]][1]["m_IsActive"] == 1
    box = rect_in([0,0,1920,1080], holder)
    assert box == [688,996,544,64]
    def group(owner, gap, align):
        g, = [f for _,f in panel.values() if f.get("m_GameObject")==owner["m_GameObject"] and "m_Spacing" in f]
        assert g["m_Enabled"] == 1 and g["m_Spacing"] == gap and g["m_ChildAlignment"] == align
        assert g["m_ChildForceExpandWidth"] == g["m_ChildForceExpandHeight"] == 1
        assert all(g[k]==0 for k in ("m_ChildControlWidth","m_ChildControlHeight","m_ChildScaleWidth",
                   "m_ChildScaleHeight","m_ReverseArrangement"))
        assert not any(g["m_Padding"].values())
    group(holder,0,4)
    footer = []
    cursor = box[0]
    specs = ((7,"Select",4,277108544247156642,6693613559686720494),
             (8,"Close",1,9176406346159490636,112357866695858735))
    assert len(holder["m_Children"]) == len(specs)
    for (action,text,alignment,txt_id,img_id), ref in zip(specs,holder["m_Children"]):
        child = panel[ref["fileID"]][1]
        assert child["m_Father"] == {"fileID":parent_id}
        assert child["m_SizeDelta"] == {"x":264,"y":64}
        assert panel[child["m_GameObject"]["fileID"]][1]["m_IsActive"] == 1
        group(child,20,0)
        # Fixed-size children in flexible 272-wide cells are centered within
        # each respective cell, not placed next to each other at box center.
        cell = box[2]/len(specs)
        x = cursor + (cell-child["m_SizeDelta"]["x"])/2
        label, image = panel[txt_id][1], panel[img_id][1]
        binding, = [f for _,f in panel.values() if f.get("m_GameObject")==child["m_GameObject"]
                    and f.get("m_Script",{}).get("guid")==button_guid]
        assert binding["m_Enabled"] == 1 and binding["m_action"] == action
        assert binding["m_image"] == {"fileID":img_id} and binding["m_spriteRenderer"] == {"fileID":0}
        assert image["m_Sprite"] == {"fileID":0} and image["m_Enabled"] == 1
        assert label["m_text"] == text and label["m_Enabled"] == label["m_RaycastTarget"] == 1
        expected = [label["m_GameObject"],image["m_GameObject"]] if action==7 else [image["m_GameObject"],label["m_GameObject"]]
        children = [panel[r["fileID"]][1] for r in child["m_Children"]]
        assert [r["m_GameObject"] for r in children] == expected
        for part in children:
            assert panel[part["m_GameObject"]["fileID"]][1]["m_IsActive"] == 1
        assert [r["m_SizeDelta"] for r in children] == [{"x":180 if n==label["m_GameObject"] else 64,"y":64} for n in expected]
        label_bounds = [x+(0 if action==7 else 84),box[1],180,64]
        icon_bounds = [x+(200 if action==7 else 0),box[1],64,64]
        footer.append(dict(single_line(label,alignment,0,64), text=text, action=action,
                           rect=label_bounds, icon_rect=icon_bounds, raycast=True))
        cursor += cell
    return {"icons_visible":False,"bounds":box,"labels":footer}


def extract(repo):
    src = {}
    def load(path):
        raw = read(repo, path)
        src[path] = hashlib.sha256(raw).hexdigest()
        return raw

    scene = load(SCENE).decode()
    root = docs(load(ROOT))
    rguid = yaml.safe_load(load(ROOT + ".meta"))["guid"]
    assert root[8778085468100695021][0] == "GameObject"
    assert re.search(r"m_uiPrefab: \{fileID: 8778085468100695021, guid: " + rguid + r", type: 3\}", scene, re.I)
    stack, = by_field(root, "m_registeredMenuPanels")
    panels = {entry["m_menu"]: entry["m_panelType"]["m_assemblyQualifiedName"].split(",")[0].split(".")[-1]
              for entry in stack["m_registeredMenuPanels"]}
    assert stack["m_Enabled"] == 1 and stack["m_stackName"] == "fw_menu"
    assert panels[0] == Path(PANEL).stem
    canvas, = [v for v in by_field(root, "m_ReferenceResolution") if v["m_ReferenceResolution"] == {"x":1920,"y":1080}]
    assert canvas["m_MatchWidthOrHeight"] == 1 and canvas["m_ReferencePixelsPerUnit"] == 96
    assert "Assets/GameRes/UI/Panels" in load("Assets/BundleCollectorSetting.asset").decode()

    maps = {item["name"]: item for item in json.loads(load(INPUT))["maps"]}
    for map_name, action in (("Gameplay","OpenGameMenu"),("UI","Cancel")):
        bindings = maps[map_name]["bindings"]
        assert any(binding["action"] == action and binding["path"] == "<Keyboard>/escape" for binding in bindings)
    panel = docs(load(PANEL))
    assert src[PANEL] == PAUSE_SHA
    controller = panel[PAUSE_COMPONENT][1]
    assert controller["m_Enabled"] == 1 and not controller["m_disableWhileOpened"]
    # 嵌套六项不是六个散落按钮；始终由具体 stripped 组件解析它的实际覆盖。
    entries = []
    for ref in controller["m_menus"]:
        sid = ref["fileID"]
        entry = panel[sid][1]
        iid = entry["m_PrefabInstance"]["fileID"]
        modifications = panel[iid][1]["m_Modification"]["m_Modifications"]
        action, = [int(m["value"]) for m in modifications if m["propertyPath"] == "m_action"]
        labels = [m["value"] for m in modifications if m["propertyPath"] == "m_text"]
        text = labels[0] if labels else "Items"
        entries.append({"id":str(sid),"prefab_instance":str(iid),"action":action,"label":text})
    assert set(x["action"] for x in entries) == {1,2,3,4,5,7}
    assert set(x["label"] for x in entries) == {"Character","Items","Abilities","Journal","Save","Settings"}
    menu_entry = docs(load(ENTRY))
    entry_guid = yaml.safe_load(load(ENTRY+".meta"))["guid"]
    script_guid = yaml.safe_load(load(ENTRY_SCRIPT+".meta"))["guid"]
    config_guid = yaml.safe_load(load(CONFIG+".meta"))["guid"]
    assert re.search(r"m_config: \{fileID: 11400000, guid: "+config_guid+r", type: 2\}",scene)
    config, = by_field(docs(load(CONFIG)), "m_onTheGoCraftingStation")
    mentioned = [v for _,v in (*panel.values(),*menu_entry.values())]
    importer = yaml.safe_load(load(ATLAS + ".meta"))
    guid = importer["guid"]
    layout = extract_entry_layout(panel, menu_entry, entry_guid, guid, config, load(ENTRY_SCRIPT).decode(), script_guid, entries)
    atlas = importer["TextureImporter"]
    sprites = {str(s["internalID"]):{"name":s["name"],"rect":s["rect"],"border":s["border"]}
               for s in atlas["spriteSheet"]["sprites"]}
    required_ids = set(str(fid) for value in mentioned for fid in refs(value,guid) if fid != 0)
    assert required_ids and required_ids.issubset(sprites)
    lfs = re.fullmatch(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([a-f0-9]{64})\nsize (\d+)\n",load(ATLAS))
    assert lfs
    assert atlas["spritePixelsToUnits"] == 16 and atlas["textureSettings"]["filterMode"] == 0
    tiled_images = {}
    for name, image_id in (("Menu Items", 6019784257370524898), ("Frame", 6368115403323056132)):
        image = panel[image_id][1]
        assert panel[image["m_GameObject"]["fileID"]][1]["m_Name"] == name
        assert image["m_Type"] == 2 and image["m_Material"]["fileID"] == 0
        assert image["m_Sprite"]["guid"] == guid and image["m_Enabled"] == 1
        assert image["m_FillCenter"] == 1 and image["m_PixelsPerUnitMultiplier"] == 1
        assert image["m_Color"] == dict(r=1, g=1, b=1, a=1)
        tiled_images[name] = {"sprite_id": str(image["m_Sprite"]["fileID"]),
                              "color": image["m_Color"], "fill_center": bool(image["m_FillCenter"]),
                              "ppu_multiplier": image["m_PixelsPerUnitMultiplier"]}
    font = docs(load(FONT))
    font_doc, = by_field(font,"m_GlyphTable")
    face = font_doc["m_FaceInfo"]
    material = font[font_doc["m_Material"]["fileID"]][1]
    assert material["m_Shader"]["guid"] == yaml.safe_load(load(FONT_SHADER+".meta"))["guid"]
    shader = load(FONT_SHADER).decode()
    include = load(FONT_INCLUDE).decode()
    assert "float sd = (bias - c) * scale;" in " ".join(shader.split())
    assert "float bias =(.5 - weight) + (.5 / scale);" in " ".join(shader.split())
    assert "faceColor *= faceAlpha;" in " ".join(include.split())
    assert not material["m_ValidKeywords"] and not material["m_InvalidKeywords"]
    floats = {key: value for entry in material["m_SavedProperties"]["m_Floats"] for key,value in entry.items()}
    colors = {key: value for entry in material["m_SavedProperties"]["m_Colors"] for key,value in entry.items()}
    assert all(floats[k] == 0 for k in ("_FaceDilate","_OutlineWidth","_OutlineSoftness","_Sharpness","_VertexOffsetX","_VertexOffsetY"))
    assert floats["_ScaleX"] == floats["_ScaleY"] == 1 and colors["_FaceColor"] == dict(r=1,g=1,b=1,a=1)
    assert not font_doc["m_FontFeatureTable"]["m_GlyphPairAdjustmentRecords"]
    font_material = {"gradient":floats["_GradientScale"], "normal_weight":floats["_WeightNormal"],
                     "bold_weight":floats["_WeightBold"], "scale_ratio":floats["_ScaleRatioA"],
                     "atlas_padding":font_doc["m_AtlasPadding"]}
    atlas_id, = font_doc["m_AtlasTextures"]
    atlas_tex = font[atlas_id["fileID"]][1]
    assert atlas_tex["m_TextureFormat"] == 1 and atlas_tex["m_Width"] == atlas_tex["m_Height"] == 1024
    font_alpha = bytes.fromhex(atlas_tex["_typelessdata"])
    assert len(font_alpha) == 1024**2
    table = {row["m_Unicode"]:row["m_GlyphIndex"] for row in font_doc["m_CharacterTable"]}
    title = panel[2442221623608319547][1]
    entry_text = menu_entry[7569937386815868997][1]
    font_guid = yaml.safe_load(load(FONT+".meta"))["guid"]
    def single_line(component, horizontal, style, size):
        assert component["m_fontAsset"]["guid"] == font_guid
        assert component["m_sharedMaterial"]["guid"] == font_guid
        assert component["m_sharedMaterial"]["fileID"] == font_doc["m_Material"]["fileID"]
        assert component["m_HorizontalAlignment"] == horizontal and component["m_VerticalAlignment"] == 512
        assert component["m_fontStyle"] == style and component["m_fontSize"] == size
        assert component["m_fontColor"] == dict(r=1,g=1,b=1,a=1)
        assert component["m_fontWeight"] == 400 and not component["m_enableVertexGradient"]
        assert all(component[k] == 0 for k in ("m_enableAutoSizing","m_isRightToLeft","m_characterSpacing",
                   "m_wordSpacing","m_lineSpacing","m_enableExtraPadding","m_overflowMode"))
        assert not any(component["m_margin"].values())
        return {"horizontal":horizontal,"vertical":512,"style":style,"size":size}
    assert title["m_text"] == "Pause"
    screen = [0,0,1920,1080]
    shade_rect = panel[2149048015533745604][1]
    shade = panel[5769781364363093463][1]
    assert shade["m_Sprite"] == shade["m_Material"] == {"fileID":0}
    assert shade["m_Enabled"] == shade["m_RaycastTarget"] == 1 and shade["m_Type"] == 0
    assert rect_in(screen,shade_rect) == screen
    effects_root = panel[7564345041676038729][1]
    effects_title = panel[7385145389262844412][1]
    effect_label = panel[6290802774718684436][1]
    assert effects_title["m_Enabled"] == effects_title["m_RaycastTarget"] == 1
    assert effects_title["m_text"] == "Active Effects"
    assert effects_root["m_AnchorMin"] == effects_root["m_AnchorMax"] == {"x":1,"y":0.5}
    assert effects_root["m_Children"][0]["fileID"] == 6290802774718684436
    text_layout = {"title":dict(single_line(title,2,17,80), text=title["m_text"],
                               rect=rect_in([0,0,1920,1080],panel[5715786672916362777][1])),
                   "entry":single_line(entry_text,1,0,64)}
    text_layout["effects_title"] = dict(single_line(effects_title,2,0,64),text=effects_title["m_text"],
                                       rect=rect_in(rect_in(screen,effects_root),effect_label))
    text_layout["default_footer"] = extract_default_footer(panel,root,load,single_line)
    assert font_doc["normalSpacingOffset"] == font_doc["normalStyle"] == 0
    assert font_doc["boldStyle"] == .75 and font_doc["boldSpacing"] == 7
    assert not any(r["regularTypeface"]["fileID"] or r["italicTypeface"]["fileID"]
                   for r in font_doc["m_FontWeightTable"])
    strings = [title["m_text"].upper(), effects_title["m_text"], *(x["label"] for x in layout["rows"]),
               *(x["text"] for x in text_layout["default_footer"]["labels"])]
    used = set(map(ord,"".join(strings)))
    assert all(r["m_Scale"] == 1 for r in font_doc["m_CharacterTable"] if r["m_Unicode"] in used)
    missing = sorted(set(map(ord,"".join(strings))) - set(table))
    assert not missing, missing
    def exact_refs(value):
        if isinstance(value, dict):
            return {key: str(child) if key == "fileID" and isinstance(child, int)
                    else exact_refs(child) for key, child in value.items()}
        if isinstance(value, list):
            return [exact_refs(item) for item in value]
        return value

    visual_records = {}
    for key,(kind,fields) in panel.items():
        if kind not in ("RectTransform","PrefabInstance","MonoBehaviour"): continue
        if kind == "MonoBehaviour" and not any(k in fields for k in ("m_text","m_Sprite","m_Spacing","m_ChildAlignment","m_FadeDuration")):
            continue
        if kind == "MonoBehaviour" and set(fields).issubset({"m_CorrespondingSourceObject","m_PrefabInstance","m_PrefabAsset","m_GameObject","m_Script","m_Name","m_EditorClassIdentifier"}):
            continue
        visual_records[str(key)] = {"type":kind,"fields":exact_refs(fields)}
    return {"schema":1,"source_commit":SOURCE,"dependencies":src,"registration":panels,"stack":"fw_menu",
            "reference_canvas":[1920,1080],"entries":entries,"entry_layout":layout,"atlas_sha256":lfs[1].decode(),
            "atlas_size":int(lfs[2]),"tiled_images":tiled_images,
            "canvas_reference_ppu":canvas["m_ReferencePixelsPerUnit"],"sprite_ppu":atlas["spritePixelsToUnits"],"sprites":{i:sprites[i] for i in sorted(required_ids)},
            "font_alpha_sha256":hashlib.sha256(font_alpha).hexdigest(),"font_face":face,
            "font_letters":table,"font_glyphs":font_doc["m_GlyphTable"],"font_material":font_material,
            "text_layout":text_layout,"font_spacing":{"normal":font_doc["normalSpacingOffset"],
                         "bold":font_doc["boldSpacing"],"bold_style":font_doc["boldStyle"]},
            "shade":panel[5769781364363093463][1]["m_Color"],"visual_records":visual_records,
            "audio":{k:controller[k]["guid"] for k in ("m_pauseSound","m_resumeSound")}}, font_alpha


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--repo",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    args = p.parse_args()
    contract, font_alpha = extract(args.repo)
    args.output.mkdir(parents=True,exist_ok=True)
    (args.output/"pause-contract.json").write_text(json.dumps(contract,ensure_ascii=False,indent=2)+"\n")
    (args.output/"pause-font-atlas.bin").write_bytes(font_alpha)
    print("PASS 原暂停菜单：绑定、实际条目布局、图集索引与嵌入字体已验证。")
