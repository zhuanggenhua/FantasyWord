#!/usr/bin/env python3
"""Extract the pinned Settings prefab structure, not its proprietary resources."""
import argparse
import hashlib
import json
from pathlib import Path

import yaml

from extract_clickmovetest_pause import ATLAS, FONT, SOURCE, docs, read, rect_in

BASE = "Assets/Prefabs/UI/MenuParts/Frames/Base Menu.prefab"
PANEL = "Assets/GameRes/UI/Panels/UISettings.prefab"
UI = "Assets/Prefabs/UI/User Interface.prefab"
MASTER = 4167515949943877772


def extract(repo):
    dependencies = {}

    def load(path):
        raw = read(repo, path)
        dependencies[path] = hashlib.sha256(raw).hexdigest()
        return raw

    panel = docs(load(PANEL))
    base = docs(load(BASE))
    ui = docs(load(UI))
    base_guid = yaml.safe_load(load(BASE + ".meta"))["guid"]
    instance = panel[5352633325423642899][1]
    assert instance["m_SourcePrefab"]["guid"] == base_guid
    mods = instance["m_Modification"]["m_Modifications"]
    assert not instance["m_Modification"]["m_RemovedComponents"]
    assert not instance["m_Modification"]["m_RemovedGameObjects"]
    assert {m["value"] for m in mods if m["target"]["fileID"]==2915058637345498972
            and m["propertyPath"]=="m_text"} == {"Settings"}
    assert instance["m_Modification"]["m_AddedComponents"][0]["addedObject"]["fileID"] == 2189263344777942897
    assert instance["m_Modification"]["m_AddedGameObjects"][0]["addedObject"]["fileID"] == 1121910985831499302
    registration, = [f for _, f in ui.values() if "m_registeredMenuPanels" in f]
    settings, = [r for r in registration["m_registeredMenuPanels"] if r["m_menu"]==6]
    assert settings["m_panelType"]["m_assemblyQualifiedName"].split(",")[0].endswith(".UISettings")
    volume = panel[2189263344777942897][1]
    assert volume["m_Enabled"]==1 and volume["m_masterVolume"]=={"fileID":MASTER}
    assert volume["m_volumeStep"]==0.1 and volume["m_volumeSuffix"]==" / 10" and volume["m_maxVolume"]==10

    font_guid = yaml.safe_load(load(FONT + ".meta"))["guid"]
    font, = [f for _, f in docs(load(FONT)).values() if "m_CharacterTable" in f]
    used = set()
    def label(f, text, size, h, v, bounds, overflow=0):
        assert f["m_Enabled"]==f["m_RaycastTarget"]==1
        assert f["m_fontAsset"]["guid"]==f["m_sharedMaterial"]["guid"]==font_guid
        assert f["m_sharedMaterial"]["fileID"]==font["m_Material"]["fileID"]
        assert f["m_fontSize"]==size and f["m_HorizontalAlignment"]==h and f["m_VerticalAlignment"]==v
        assert f["m_fontStyle"]==0 and f["m_fontWeight"]==400 and not any(f["m_margin"].values())
        assert all(f[k]==0 for k in ("m_enableAutoSizing","m_isRightToLeft","m_characterSpacing",
                   "m_wordSpacing","m_lineSpacing","m_enableExtraPadding"))
        assert f["m_overflowMode"] == overflow
        used.update(set(text) - {"\n"})
        return dict(text=text, size=size, horizontal=h, vertical=v, style=0, rect=bounds, color=f["m_fontColor"], overflow=overflow)

    def rect_for(model, obj):
        r, = [f for kind,f in model.values() if kind=="RectTransform" and f.get("m_GameObject")==obj]
        return r

    def group(model, obj, align, spacing, width_expand, height_expand):
        g, = [f for _,f in model.values() if f.get("m_GameObject")==obj and "m_Spacing" in f]
        assert g["m_Enabled"]==1 and g["m_ChildAlignment"]==align and g["m_Spacing"]==spacing
        assert (g["m_ChildForceExpandWidth"], g["m_ChildForceExpandHeight"]) == (width_expand, height_expand)
        assert all(g[k]==0 for k in ("m_ChildControlWidth","m_ChildControlHeight",
                   "m_ChildScaleWidth","m_ChildScaleHeight","m_ReverseArrangement"))
        assert not any(g["m_Padding"].values())

    screen = [0,0,1920,1080]
    root = base[5585640409129449731][1]
    assert rect_in(screen,root)==screen
    holder = base[625290108352659364][1]
    content = rect_in(screen,holder)
    title_rect = rect_in(content,base[8269007978594452267][1])
    assert title_rect==[100,100,1720,120]
    title = label(base[2915058637345498972][1],"Settings",120,2,256,title_rect)
    region = panel[1121910985831499302][1]
    where = rect_in(content,region)
    assert where==[120,240,1680,720]
    group(panel,region["m_GameObject"],4,0,1,0)
    row_scripts = [volume["m_masterVolume"],*volume["m_channelVolumes"]]
    assert len(row_scripts)==len(region["m_Children"])==5
    rows = []
    titles = ("Master Volume","Background Music\n","Background Sound","Interface Sound","Gameplay Sound")
    for i,(row_ref,r) in enumerate(zip(row_scripts,region["m_Children"])):
        row, logic = panel[r["fileID"]][1], panel[row_ref["fileID"]][1]
        assert row["m_GameObject"]==logic["m_GameObject"]
        assert logic.get("m_audioChannel",-1)==i-1
        assert row["m_SizeDelta"]=={"x":866,"y":0}
        group(panel,row["m_GameObject"],3,16,1,1)
        fit, = [f for _,f in panel.values() if f.get("m_GameObject")==row["m_GameObject"] and "m_VerticalFit" in f]
        assert fit["m_HorizontalFit"]==fit["m_VerticalFit"]==2 and fit["m_Enabled"]==1
        label_id, controls_id = [c["fileID"] for c in row["m_Children"]]
        label_rect,controls = panel[label_id][1],panel[controls_id][1]
        text, = [f for _,f in panel.values() if f.get("m_GameObject")==label_rect["m_GameObject"] and "m_text" in f]
        assert text["m_text"]==titles[i]
        group(panel,controls["m_GameObject"],0,0,1,1)
        assert label_rect["m_SizeDelta"]=={"x":450,"y":64} and controls["m_SizeDelta"]=={"x":400,"y":64}
        assert len(controls["m_Children"])==3
        x,y = where[0]+(where[2]-866)/2, where[1]+(where[3]-320)/2+64*i
        result = {"id":i-1,"label":label(text,titles[i],64,1,512,[x,y,450,64],overflow=1)}
        rx=x+466
        for kind,child,w,txt in zip(("decrease","value","increase"),controls["m_Children"],(64,272,64),("<","{value}",">")):
            part = panel[child["fileID"]][1]
            assert part["m_SizeDelta"]=={"x":w,"y":64}
            component = panel[logic[f"m_{kind}" if kind=="value" else f"m_{kind}Button"]["fileID"]][1]
            assert part["m_GameObject"]==component["m_GameObject"]
            if kind!="value":
                colors = component["m_Colors"]
                assert component["m_Enabled"]==component["m_Interactable"]==component["m_Transition"]==1
                assert component["m_Navigation"]["m_Mode"]==3 and not component["m_Navigation"]["m_WrapAround"]
                assert colors["m_FadeDuration"]==0.1 and colors["m_ColorMultiplier"]==1
                assert colors["m_NormalColor"]["a"]==0.39215687 and all(colors["m_"+name+"Color"]["a"]==1
                        for name in ("Highlighted","Pressed","Selected","Disabled"))
                component = panel[component["m_TargetGraphic"]["fileID"]][1]
            assert component["m_text"]==txt
            result[kind] = label(component,"0123456789 /" if kind=="value" else txt,64,2,512,[rx,y,w,64])
            if kind=="value": result[kind]["text"]=txt
            rx+=w
        rows.append(result)

    importer = yaml.safe_load(load(ATLAS+".meta"))
    image = base[6380586684605756007][1]
    assert image["m_Sprite"]["guid"]==importer["guid"] and image["m_Sprite"]["fileID"]==-1443275623
    assert (image["m_Enabled"],image["m_RaycastTarget"],image["m_Type"],image["m_FillCenter"],image["m_PixelsPerUnitMultiplier"])==(1,1,2,1,1)
    assert image["m_Color"]==dict(r=1,g=1,b=1,a=1) and rect_in(screen,rect_for(base,image["m_GameObject"]))==screen
    tex=importer["TextureImporter"]
    assert tex["spritePixelsToUnits"]==16 and tex["textureSettings"]["filterMode"]==0
    sprite, = [s for s in tex["spriteSheet"]["sprites"] if s["internalID"]==-1443275623]
    assert sprite["rect"]==dict(serializedVersion=2,x=96,y=88,width=24,height=24)
    assert sprite["border"]==dict(x=3,y=3,z=3,w=3)
    footer=[label(base[3950320686320582774][1],"Select",64,1,512,[104,996,180,64]),
            label(base[8205313523415547342][1],"Back",64,4,512,[1636,996,180,64])]
    assert dependencies[PANEL] == "8ca6df7f491c9fc29b0b12ef300cf0af9952f16a3295ae310e6050fec864d2b2"
    assert dependencies[BASE] == "9e8edb34266ca0095a5a5325d334129dae92e55d9828b1454499aef9f12ad728"
    assert used.issubset({chr(int(r["m_Unicode"])) for r in font["m_CharacterTable"]})
    return {"schema":1,"source_commit":SOURCE,"dependencies":dependencies,"rows":rows,
            "root_rect":screen,"title":title,"footer":footer,"default_focus":[-1,-1],
            "tile":{"id":"-1443275623","rect":[96,88,24,24],"border":[3,3,3,3],"pixel_size":6},
            "volume":{"step":volume["m_volumeStep"],"suffix":volume["m_volumeSuffix"],"max":volume["m_maxVolume"]}}


if __name__ == "__main__":
    cli=argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--repo",type=Path,required=True)
    cli.add_argument("--output",type=Path,required=True)
    args=cli.parse_args()
    result=extract(args.repo)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("PASS Settings resolved five bound rows, typography and tiled background.")
