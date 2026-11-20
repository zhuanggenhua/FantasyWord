#!/usr/bin/env python3
"""Extract authored empty ClickMoveTest Journal UI pixels/geometry, not assets."""
import argparse
import hashlib
import json
from pathlib import Path

import yaml

from extract_clickmovetest_character_layout import BASE, fixed_children, override
from extract_clickmovetest_pause import ATLAS, FONT, ROOT, SCENE, SOURCE, docs, read, rect_in

PANEL = "Assets/GameRes/UI/Panels/UIJournal.prefab"
RUNTIME = "Assets/Scripts/GameCore/Runtime/"


def expanded_column(parent, sizes, fields):
    # UGUI expands each layout allocation even with controlHeight disabled,
    # but retains the child's own height and puts it at the top of that cell.
    assert not any(fields["m_Padding"].values())
    assert fields["m_ChildAlignment"] == fields["m_Spacing"] == fields["m_ChildControlHeight"] == 0
    assert fields["m_ChildForceExpandHeight"] == 1
    gap = (parent[3]-sum(h for _,h in sizes))/len(sizes)
    assert gap >= 0
    y = parent[1]
    rows = []
    for width,height in sizes:
        rows.append([parent[0],y,width,height])
        y += height+gap
    return rows


def extract(repo):
    hashes = {}

    def raw(path):
        data = read(repo, path)
        hashes[path] = hashlib.sha256(data).hexdigest()
        return data

    def guid(path):
        return yaml.safe_load(raw(path + ".meta"))["guid"]

    def model(path):
        return {i: row for i, (_, row) in docs(raw(path)).items()}

    def size(row):
        return [row["m_SizeDelta"][a] for a in "xy"]

    registration = raw(ROOT).decode()
    assert "m_menu: 4\n    m_panelType:\n      m_assemblyQualifiedName: FantasyWord.GameCore.UIJournal, FantasyWord.GameCore" in registration
    actions = raw(RUNTIME+"UI/Menus/UIGameMenuEntry.cs").decode()
    assert actions.index("OpenInventory,") < actions.index("OpenJournal,") < actions.index("OpenCraft,")
    assert "GameRuntimeEvents.RequestMenu(EMenu.Journal);" in actions
    raw(SCENE)
    raw(RUNTIME+"Game/Systems/JournalSystem.cs")
    for name in ("UIJournal", "UIJournalQuestEntry", "UIJournalQuestDescription"):
        raw(RUNTIME+"UI/Menus/Journal/"+name+".cs")

    panel, base = model(PANEL), model(BASE)
    scene = [0,0,1920,1080]
    instance = panel[4074243227707515928]
    base_id = guid(BASE)
    assert instance["m_SourcePrefab"]["guid"] == base_id
    assert instance["m_Modification"]["m_AddedGameObjects"] == [{
        "targetCorrespondingSourceObject":{"fileID":625290108352659364,"guid":base_id,"type":3},
        "insertIndex":-1,"addedObject":{"fileID":1721441528}}]
    assert panel[1473320383]["m_questEntryPoolSize"] == 100
    assert panel[1473320383]["m_questListRoot"]["fileID"] == 1525988525
    safe = rect_in(scene,base[625290108352659364])
    group = panel[1721441530]
    content_def = panel[1721441528].copy()
    child_ids = [child["fileID"] for child in content_def["m_Children"]]
    assert child_ids == [5236704620743489318,6055299368288766680] and group["m_Spacing"] == 16
    sizes = [size(panel[i]) for i in child_ids]
    fitter = panel[1721441529]
    assert fitter["m_HorizontalFit"] == fitter["m_VerticalFit"] == 2
    content_def["m_SizeDelta"] = {"x":sum(w for w,_ in sizes)+group["m_Spacing"],"y":max(h for _,h in sizes)}
    content = rect_in(safe,content_def)
    columns = fixed_children(content,sizes,group,False)

    s = {row["internalID"]:{"id":str(row["internalID"]),"rect":row["rect"],"border":row["border"]}
         for row in yaml.safe_load(raw(ATLAS+".meta"))["TextureImporter"]["spriteSheet"]["sprites"]}
    atlas_id, font_id = guid(ATLAS), guid(FONT)

    def label(q, box, anchor):
        assert q["m_fontAsset"]["guid"] == font_id and not q["m_fontStyle"] and not q["m_enableAutoSizing"]
        assert not any(q["m_margin"].values())
        return {"text":q["m_text"],"rect":box,"anchor":anchor,"size":q["m_fontSize"],"style":q["m_fontStyle"],
                "horizontal":q["m_HorizontalAlignment"],"vertical":q["m_VerticalAlignment"],
                "overflow":q["m_overflowMode"],"color":q["m_fontColor"]}

    header = override(base[2915058637345498972],instance,2915058637345498972)
    labels = [label(header,rect_in(safe,base[8269007978594452267]),"center")]
    controls = rect_in(scene,base[2944192064461780042])
    for root,logic,text_id,anchor in (
            (4105550822655348061,7229279712121902982,3950320686320582774,"left"),
            (7796335642725989680,3979155824425089242,8205313523415547342,"right")):
        entries = [base[child["fileID"]] for child in base[root]["m_Children"]]
        boxes = fixed_children(rect_in(controls,base[root]),[size(c) for c in entries],base[logic],False)
        for row,box in zip(entries,boxes,strict=True):
            if row["m_GameObject"] == base[text_id]["m_GameObject"]:
                labels.append(label(override(base[text_id],instance,text_id),box,anchor))

    backgrounds, viewports = [], []
    for index,(layout_id, ids, text_id, images, viewport, mask) in enumerate([
            (8827750697826763729,(6899097779739484883,1954872513),3998889979980909945,
                ([191504606,191504607],[301042533,301042534]),739754821,739754822),
            (6431420179500941409,(3575969459144853471,788078063),1136256935265592049,
                ([1937041880,1937041881],[820909028,820909029]),1103687060,1103687061)]):
        label_box, region = expanded_column(columns[index],[size(panel[i]) for i in ids],panel[layout_id])
        labels.append(label(panel[text_id],label_box,"center"))
        for rect_id,image_id in images:
            image = panel[image_id]
            assert image["m_Type"]==1 and image["m_FillCenter"] and image["m_PixelsPerUnitMultiplier"]==1
            assert image["m_Sprite"]["guid"]==atlas_id and all(v==1 for v in image["m_Color"].values())
            backgrounds.append({"rect":rect_in(region,panel[rect_id]),"sprite":s[image["m_Sprite"]["fileID"]]})
        assert panel[mask]["m_ShowMaskGraphic"]==0
        viewports.append(rect_in(region,panel[viewport]))
    scrollbar = panel[1954872515]
    assert not scrollbar["m_Horizontal"] and scrollbar["m_Vertical"] and scrollbar["m_VerticalScrollbarVisibility"]==1
    tile = base[6380586684605756007]
    assert tile["m_Type"]==2 and tile["m_Sprite"]["guid"]==atlas_id
    return {"schema":1,"source_commit":SOURCE,"pause_action":2,"registration":4,"labels":labels,
            "empty_viewports":viewports,"backgrounds":backgrounds,"tile":s[tile["m_Sprite"]["fileID"]],
            "dependencies":hashes}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--repo",required=True,type=Path)
    p.add_argument("--out",required=True,type=Path)
    a = p.parse_args()
    a.out.write_text(json.dumps(extract(a.repo),ensure_ascii=False,sort_keys=True,indent=2)+"\n")
