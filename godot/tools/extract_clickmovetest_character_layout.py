#!/usr/bin/env python3
"""Resolve the locked UICharacter's inherited UGUI layout and term receivers.

Output belongs with private source contracts. Reference boxes are at 1920x1080;
their anchors describe what tracks the center, right, bottom or canvas width.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

import yaml

from extract_clickmovetest_character import BASE, PANEL, ROW, extract as extract_state
from extract_clickmovetest_pause import ATLAS, CONFIG, FONT, ROOT, SCENE, SOURCE, docs, read, rect_in

TERM = "Assets/Prefabs/UI/MenuParts/Stats/Term With Value.prefab"
BUTTON = "Assets/Prefabs/UI/Generic/Button.prefab"
SCRIPTS = "Assets/Scripts/GameCore/Runtime/"
PRIMARY = "11400000"
TMP = "Assets/TextMesh Pro/Resources/TMP Settings.asset"
SILVER = "Assets/Fonts/Silver SDF.asset"
FALLBACK = "Assets/Fonts/Silver CJK Fallback SDF.asset"
SILVER_TTF = "Assets/Fonts/Silver.ttf"


def override(fields, instance, file_id):
    """Apply scalar/RectTransform component overrides; ignore other metadata."""
    result = deepcopy(fields)
    for m in instance["m_Modification"]["m_Modifications"]:
        if m["target"]["fileID"] != file_id:
            continue
        key, dot, attr = m["propertyPath"].partition(".")
        if not dot and key in result and not isinstance(result[key], (dict, list)):
            result[key] = m["value"]
        elif dot and key in result and isinstance(result[key], dict) and attr in result[key]:
            result[key][attr] = m["value"]
    return result


def fixed_children(parent, sizes, group, vertical):
    """HorizontalOrVerticalLayoutGroup subset with uncontrolled child sizes."""
    assert group["m_Enabled"] == 1
    assert not any(group["m_Padding"].values())
    assert not any(group.get(k, 0) for k in (
        "m_ChildControlWidth", "m_ChildControlHeight", "m_ChildScaleWidth",
        "m_ChildScaleHeight", "m_ReverseArrangement"))
    axis, cross = (1, 0) if vertical else (0, 1)
    alignment = (group["m_ChildAlignment"] % 3 / 2, group["m_ChildAlignment"] // 3 / 2)
    space = group["m_Spacing"]
    preferred = sum(s[axis] for s in sizes) + (len(sizes) - 1) * space
    cursor = (parent[axis + 2] - preferred) * alignment[axis]
    boxes = []
    for size in sizes:
        at = list(parent[:2])
        at[axis] += cursor
        at[cross] += (parent[cross + 2] - size[cross]) * alignment[cross]
        boxes.append([*at, *size])
        cursor += size[axis] + space
    return boxes


def extract(repo):
    state = extract_state(repo)
    dependencies = state["dependencies"].copy()

    def load(path):
        raw = read(repo, path)
        dependencies[path] = hashlib.sha256(raw).hexdigest()
        return raw

    def guid(path):
        return yaml.safe_load(load(path + ".meta"))["guid"]

    def size(fields):
        return [fields["m_SizeDelta"][a] for a in "xy"]

    def model(path):
        return {i: row for i, (_, row) in docs(load(path)).items()}

    panel, base, row, term, button = map(model, (PANEL, BASE, ROW, TERM, BUTTON))
    base_instance = panel[1257309155729834875]
    base_c = base_instance["m_Modification"]
    assert base_instance["m_SourcePrefab"]["guid"] == guid(BASE)
    assert not base_c["m_RemovedGameObjects"] and not base_c["m_RemovedComponents"]
    assert base_c["m_AddedGameObjects"] == [{
        "targetCorrespondingSourceObject": {"fileID":625290108352659364, "guid":guid(BASE), "type":3},
        "insertIndex":-1, "addedObject":{"fileID":1451353988}}]
    font_guid = guid(FONT)
    font, = [f for _, f in docs(load(FONT)).values() if "m_CharacterTable" in f]
    supported = {chr(g["m_Unicode"]) for g in font["m_CharacterTable"]}

    def asset(path):
        return {i: row for i, (_,row) in docs(load(path)).items()}[int(PRIMARY)]

    tmp = asset(TMP)
    silver = asset(SILVER)
    cjk = asset(FALLBACK)
    assert tmp["m_defaultFontAsset"]["guid"]==guid(SILVER)
    assert not tmp["m_fallbackFontAssets"] and not font["m_FallbackFontAssetTable"]
    assert silver["m_AtlasPopulationMode"]==cjk["m_AtlasPopulationMode"]==1
    assert silver["m_FallbackFontAssetTable"]==[{"fileID":int(PRIMARY),"guid":guid(FALLBACK),"type":2}]
    assert silver["m_SourceFontFileGUID"]==guid(SILVER_TTF)
    font_owners = {"primary":font_guid,"default":guid(SILVER),"secondary":guid(FALLBACK),
                  "default_face":silver["m_FaceInfo"]}

    def label(f, bounds, text=None, anchor="center"):
        assert f["m_Enabled"] == 1 and f["m_fontStyle"] == 0 and f["m_fontWeight"] == 400
        assert f["m_fontAsset"] == {"fileID":int(PRIMARY), "guid":font_guid, "type":2}
        assert f["m_sharedMaterial"] == {"fileID":font["m_Material"]["fileID"], "guid":font_guid, "type":2}
        assert not any(f["m_margin"].values())
        assert not any(f[k] for k in ("m_enableAutoSizing", "m_isRightToLeft", "m_characterSpacing",
                                     "m_wordSpacing", "m_lineSpacing","m_enableExtraPadding"))
        return {"text":f["m_text"] if text is None else text, "rect":bounds, "anchor":anchor,
                "size":f["m_fontSize"], "horizontal":f["m_HorizontalAlignment"],
                "vertical":f["m_VerticalAlignment"], "style":f["m_fontStyle"],
                "color":f["m_fontColor"], "overflow":f["m_overflowMode"]}

    assert f"m_config: {{fileID: {PRIMARY}, guid: {guid(CONFIG)}, type: 2}}" in load(SCENE).decode()
    config = model(CONFIG)[int(PRIMARY)]
    terms = config["m_gameTerms"]
    term_by_id = dict(zip(terms["m_keys"] or [], terms["m_values"], strict=True))
    code = load(SCRIPTS+"Game/GameConfig.Terms.cs").decode()
    defaults = {k: re.search(rf'{k} = "(\[INVALID_[A-Z]+\])"', code)[1] for k in ("fullName","shortName")}
    load(SCRIPTS+"UI/Generic/UITerm.cs")

    def term_label(fields):
        t = term_by_id.get(fields["m_termID"], defaults)
        return fields["m_textFormat"].format(t["fullName" if int(fields["m_displayMode"])==0 else "shortName"])

    screen = [0,0,1920,1080]
    stretch = override(base[5585640409129449731],base_instance,5585640409129449731)
    assert stretch["m_AnchorMin"] == {"x":0,"y":0} and stretch["m_AnchorMax"] == {"x":1,"y":1}
    assert rect_in(screen,stretch) == screen
    safe = rect_in(screen,base[625290108352659364])
    title = label(override(base[2915058637345498972],base_instance,2915058637345498972),
                  rect_in(safe,base[8269007978594452267]),anchor="wide")
    footer = []
    controls = rect_in(screen,base[2944192064461780042])
    for group_id, group_logic, text_id, anchor in (
            (4105550822655348061,7229279712121902982,3950320686320582774,"bottom_left"),
            (7796335642725989680,3979155824425089242,8205313523415547342,"bottom_right")):
        group = base[group_id]
        children = [base[c["fileID"]] for c in group["m_Children"]]
        boxes = fixed_children(rect_in(controls,group),[size(c) for c in children],base[group_logic],False)
        for child, box in zip(children,boxes):
            if child["m_GameObject"] == base[text_id]["m_GameObject"]:
                footer.append(label(base[text_id],box,anchor=anchor))
    assert [x["rect"] for x in footer] == [[104,996,180,64],[1636,996,180,64]]

    controller = panel[1969439460]
    stats = panel[2104631008]
    info = panel[1316806455]
    assert panel[1451353988]["m_Children"] == [{"fileID":2104631008},{"fileID":1316806455}]
    assert all(panel[i]["m_HorizontalFit"]==panel[i]["m_VerticalFit"]==2 for i in (1451353989,2104631010,1316806457))
    row_children = [row[c["fileID"]] for c in row[104031430085134021]["m_Children"]]
    row_subsizes = [size(c) for c in row_children]
    row_height = max(s[1] for s in row_subsizes)
    term_children = [term[c["fileID"]] for c in term[4316644105286767360]["m_Children"]]
    term_sizes = [size(c) for c in term_children]
    term_height = max(s[1] for s in term_sizes)
    assert len(info["m_Children"]) == 7 and len(stats["m_Children"]) == 8
    assert info["m_Children"][5]["fileID"] == 5062227482765798721
    button_instance = panel[6071888772817055673]
    button_root = 3071031120901858107
    assert button_instance["m_SourcePrefab"]["guid"] == guid(BUTTON)
    assert panel[info["m_Children"][6]["fileID"]]["m_PrefabInstance"]["fileID"]==6071888772817055673
    click = {m["propertyPath"]:m for m in button_instance["m_Modification"]["m_Modifications"] if m["target"]["fileID"]==6454204061997250534}
    click_path = "m_OnClick.m_PersistentCalls.m_Calls.Array.data[0]."
    assert click[click_path+"m_MethodName"]["value"]=="Apply"
    assert click[click_path+"m_Target"]["objectReference"]=={"fileID":1969439460}
    button_size = size(override(button[button_root],button_instance,button_root))
    stat_sizes = [[size(stats)[0],row_height]] * 8
    info_sizes = [[size(info)[0],term_height]] * 5 + [size(panel[5062227482765798721]),button_size]
    stat_column = [size(stats)[0],sum(h for _,h in stat_sizes)]
    info_column = [size(info)[0],sum(h for _,h in info_sizes)]
    content = deepcopy(panel[1451353988])
    hg = panel[1451353990]
    content["m_SizeDelta"] = {"x":stat_column[0]+hg["m_Spacing"]+info_column[0], "y":max(stat_column[1],info_column[1])}
    columns = fixed_children(rect_in(safe,content),[stat_column,info_column],hg,False)

    rows = []
    row_guid = guid(ROW)
    for index,(ref, rec, box) in enumerate(zip(stats["m_Children"],controller["m_stats"],
            fixed_children(columns[0],stat_sizes,panel[2104631009],True),strict=True)):
        instance_id = panel[ref["fileID"]]["m_PrefabInstance"]["fileID"]
        assert panel[rec["fileID"]]["m_PrefabInstance"]["fileID"]==instance_id
        instance = panel[instance_id]
        assert instance["m_SourcePrefab"]["guid"] == row_guid
        resolved = override(row[104031430085134022],instance,104031430085134022)
        assert int(resolved["m_stat"])==index
        term_def = override(row[2292069367473478628],instance,2292069367473478628)
        assert term_def["m_optionalIcon"]=={"fileID":104031429746251558} and term_def["m_termID"] not in term_by_id
        blank = row[104031429746251558]
        assert blank["m_Enabled"]==1 and blank["m_Sprite"]=={"fileID":0} and blank["m_Type"]==0
        icon_box, label_box, controls_box = fixed_children(box,row_subsizes,row[104031430085134019],False)
        group = row[104031430241078433]
        subboxes = fixed_children(controls_box,[size(row[c["fileID"]]) for c in group["m_Children"]],
                                  row[104031430241078432],False)
        data = {"stat":index,"term_id":term_def["m_termID"],"null_icon_rect":icon_box,
                "label":label(row[term_def["m_optionalLabel"]["fileID"]],label_box,term_label(term_def))}
        fields = [("decrease",104031429754551818),("value",resolved["m_value"]["fileID"]),("increase",104031430246590497)]
        for (key,file_id),part in zip(fields,subboxes):
            comp = row[file_id]
            if key!="value":
                assert comp["m_Interactable"]==comp["m_Enabled"]==1 and comp["m_Navigation"]["m_Mode"]==3
                comp = row[comp["m_TargetGraphic"]["fileID"]]
            data[key] = label(comp,part)
        rows.append(data)

    terms_array = []
    info_boxes = fixed_children(columns[1],info_sizes,panel[1316806456],True)
    term_guid = guid(TERM)
    for name,ref,box in zip(("class","level","experience","skill_points","currency"),info["m_Children"][:5],info_boxes[:5],strict=True):
        source_key = "skillPoints" if name=="skill_points" else name
        ptr = panel[controller["m_"+source_key]["fileID"]]
        instance_id = panel[ref["fileID"]]["m_PrefabInstance"]["fileID"]
        assert ptr["m_PrefabInstance"]["fileID"]==instance_id
        assert ptr["m_CorrespondingSourceObject"]["fileID"]==4316644103916174450
        instance = panel[instance_id]
        assert instance["m_SourcePrefab"]["guid"]==term_guid
        term_def = override(term[4316644105286767361],instance,4316644105286767361)
        a,b = fixed_children(box,term_sizes,term[4316644105286767367],False)
        terms_array.append({"key":name,"term_id":term_def["m_termID"],
                            "label":label(term[term_def["m_optionalLabel"]["fileID"]],a,term_label(term_def)),
                            "value":label(term[4316644103916174450],b)})

    importer = yaml.safe_load(load(ATLAS+".meta"))
    image = button[907951424837194884]
    assert image["m_Sprite"]["guid"]==importer["guid"] and image["m_Type"]==1 and image["m_FillCenter"]==1
    tex = importer["TextureImporter"]
    assert tex["spritePixelsToUnits"]==16
    menu = docs(load(ROOT))
    canvas, = [f for _,f in menu.values() if "m_ReferencePixelsPerUnit" in f]
    assert canvas["m_ReferencePixelsPerUnit"]==96

    def sprite_geometry(ref):
        assert ref["guid"]==importer["guid"]
        sprite, = [s for s in tex["spriteSheet"]["sprites"] if s["internalID"]==ref["fileID"]]
        return {"id":str(sprite["internalID"]),"rect":[sprite["rect"][k] for k in ("x","y","width","height")],
                "border":[sprite["border"][k] for k in "xyzw"],
                "pixel_size":canvas["m_ReferencePixelsPerUnit"]/tex["spritePixelsToUnits"]}

    apply_button = button[6454204061997250534]
    assert apply_button["m_Transition"]==2 and apply_button["m_Interactable"]==1
    assert apply_button["m_TargetGraphic"]=={"fileID":907951424837194884}
    sprite_state = {"normal":sprite_geometry(image["m_Sprite"])}
    for mode in ("Highlighted","Pressed","Selected","Disabled"):
        sprite_state[mode.lower()] = sprite_geometry(apply_button["m_SpriteState"]["m_"+mode+"Sprite"])
    background = base[6380586684605756007]
    assert background["m_Type"]==2 and background["m_FillCenter"]==1
    tile = sprite_geometry(background["m_Sprite"])
    apply = {"rect":info_boxes[-1], "label":label(button[8040491482692079704],
             rect_in(info_boxes[-1],button[254863085315016615])),
             "sprite_state":sprite_state}
    assert all(set(spec["text"]) <= supported for spec in [title,*footer,*[r["label"] for r in rows+terms_array]])
    return {"schema":1,"source_commit":SOURCE,"dependencies":dependencies,"canvas":screen,
            "title":title,"footer":footer,"rows":rows,"info":terms_array,"apply":apply,
            "default_focus":{"stat":0,"button":"decrease"}, "tile":tile, "font_owners":font_owners}


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--repo",type=Path,required=True)
    cli.add_argument("--output",type=Path,required=True)
    args = cli.parse_args()
    data = extract(args.repo)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    print("PASS original UICharacter nested layout, terms, stat receivers and Apply.")
