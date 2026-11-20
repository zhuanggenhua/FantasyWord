#!/usr/bin/env python3
"""Extract final-layout ability-menu contracts while keeping authors' assets private."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import yaml
from fontTools.ttLib import TTFont

from extract_clickmovetest_character_layout import BASE, fixed_children, override
from extract_clickmovetest_pause import ATLAS, CONFIG, FONT, ROOT, SOURCE, docs, read, rect_in

PANEL = "Assets/GameRes/UI/Panels/UIAbilities.prefab"
PARTS = "Assets/Prefabs/UI/MenuParts/Abilities/"
GENERIC = "Assets/Prefabs/UI/Generic/Ability.prefab"
RUNTIME = "Assets/Scripts/GameCore/Runtime/"
GAS = "Assets/DataGenerated/Luban/Json/GAS/"
ATTACK_IMAGE = "Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon/Sprites/Animations/Human/HumanBaseAttack.png"
ATTACK_HASH = "04f45493247f314e01530012480602e169e0aa0b1dac0d0abe6c2495dd34610b"


def extract(repo, attack_image, silver_path):
    deps = {}

    def raw(path):
        data = read(repo, path)
        deps[path] = hashlib.sha256(data).hexdigest()
        return data

    def guid(path):
        return yaml.safe_load(raw(path+".meta"))["guid"]

    def model(path):
        return {key: value for key, (_,value) in docs(raw(path)).items()}

    def table(name):
        return {r["ID"]:r for r in json.loads(raw(GAS+name+".json"))}

    def dims(row):
        return [row["m_SizeDelta"][axis] for axis in "xy"]

    assert "m_menu: 2\n    m_panelType:\n      m_assemblyQualifiedName: FantasyWord.GameCore.UIAbilities, FantasyWord.GameCore" in raw(ROOT).decode()
    actions = raw(RUNTIME+"UI/Menus/UIGameMenuEntry.cs").decode()
    assert actions.index("OpenSaveMenu,") < actions.index("OpenAbilities,") < actions.index("OpenCharacter,")
    assert "GameRuntimeEvents.RequestAbilitiesMenu(CharacterMenuContext.ViewCharacter(abilitiesMenuActor));" in actions
    terms = model(CONFIG)[11400000]
    for key in ("m_gameTerms","m_abilityTypesBinding","m_damageTypesBinding"):
        assert not terms[key]["m_keys"] and not terms[key]["m_values"]
    terms_cs = raw(RUNTIME+"Game/GameConfig.Terms.cs").decode()
    invalid, = re.findall(r'shortName = "(\[INVALID_SHORTNAME\])"', terms_cs)
    def fallbacks(keys):
        return {k:re.search(r'"'+k+r'" => "([^"]+)"',terms_cs)[1] for k in keys}
    fallback = fallbacks(["flat_damage","scaled_damage","remove_health"])
    physical, = re.findall('EDamageType.Physical => "([^"]+)"',terms_cs)
    for name in ("UIAbilities","UIAbilityBar","UIAbilityBarEntry","UIAbilityCategory","UIAbilityListEntry"):
        raw(RUNTIME+"UI/Menus/Abilities/"+name+".cs")
    for name in ("Entities/Characters/CharacterAbilitySet.cs","UI/Generic/UIAbility.cs",
                 "Combat/FormalGameplayEffectDamageIntegration.cs","UI/UIManager.MenuStackRuntime.cs",
                 "UI/MenuPanels/UIKitMenuPanelBase.cs"):
        raw(RUNTIME+name)
    raw("Assets/Scripts/Gen/FormalGasAbilityDescriptionGeneratedRuntime.cs")
    for name in ("Core/Root/UIRoot.Stack.cs","Core/Root/UIRoot.PanelOperations.cs","Core/Panel/UIPanel.cs"):
        raw("Assets/Plugins/YokiFrame/Tools/UIKit/Runtime/"+name)

    panel, base, entry, category, bar_entry, generic = map(model, [
        PANEL, BASE, PARTS+"Ability List Entry.prefab", PARTS+"Ability Category.prefab",
        PARTS+"Ability Bar Entry.prefab", GENERIC])
    receiver=panel[1552621787]
    assert receiver["m_abilityListRoot"]["fileID"]==1734756565 and receiver["m_listCanvasGroup"]["fileID"]==821630662
    assert b"m_keys: 0100000000000000" in raw(PANEL)
    assert [x["fileID"] for x in receiver["m_categories"]["m_values"]]==[4215465731577672255,6063682196018617357]
    assert panel[panel[7914205530145001425]["m_GameObject"]["fileID"]]["m_IsActive"]==0
    assert [x["fileID"] for x in receiver["m_toEnableWhenEquippingAnAbility"]]==[6092532875317147905,8922816817136111810,2790686071861854702]
    assert all(panel[x]["m_IsActive"]==0 for x in (6092532875317147905,8922816817136111810,2790686071861854702))
    inst=panel[6756622685991899477]
    assert inst["m_SourcePrefab"]["guid"]==guid(BASE)
    assert inst["m_Modification"]["m_AddedGameObjects"][0]["addedObject"]["fileID"]==252827174
    scene=[0,0,1920,1080]
    safe=rect_in(scene,base[625290108352659364])
    root_def=panel[252827174].copy()
    left_def,right_def=[panel[x["fileID"]] for x in root_def["m_Children"]]
    spacing=panel[252827175]["m_Spacing"]
    sizes=[dims(left_def),dims(right_def)]
    assert panel[252827176]["m_HorizontalFit"]==panel[252827176]["m_VerticalFit"]==2
    root_def["m_SizeDelta"]={"x":sum(w for w,_ in sizes)+spacing,"y":max(h for _,h in sizes)}
    content=rect_in(safe,root_def)
    left,right=fixed_children(content,sizes,panel[252827175],False)
    category_group,list_box=fixed_children(left,[dims(panel[k]) for k in (1812042892466085118,821630661)],panel[5930059211480490478],True)
    right_title,description,bar=fixed_children(right,[dims(panel[k]) for k in (1545711250461619542,532114563,1834533895)],panel[1487127233],True)
    viewport=rect_in(list_box,panel[2090363376])
    assert panel[2090363377]["m_ShowMaskGraphic"]==0
    assert next(p["m_VerticalScrollbarVisibility"] for p in panel.values() if p.get("m_Content")=={"fileID":1734756566})==1
    assert panel[1734756568]["m_HorizontalFit"]==panel[1734756568]["m_VerticalFit"]==2
    list_group=panel[1734756567]
    assert list_group["m_ChildControlHeight"] and not list_group["m_ChildControlWidth"] and list_group["m_ChildAlignment"]==0
    row_width,row_height=dims(entry[939711528066957108])

    s={v["internalID"]:{"id":str(v["internalID"]),"rect":v["rect"],"border":v["border"]}
       for v in yaml.safe_load(raw(ATLAS+".meta"))["TextureImporter"]["spriteSheet"]["sprites"]}
    atlas_id,font_id=guid(ATLAS),guid(FONT)

    def image(row,box,flip=False):
        assert row["m_Sprite"]["guid"]==atlas_id and row["m_FillCenter"] and row["m_PixelsPerUnitMultiplier"]==1
        return {"rect":box,"sprite":s[row["m_Sprite"]["fileID"]],"type":row["m_Type"],
                "color":row["m_Color"],"flip":flip}

    def label(q,box,anchor="center"):
        assert q["m_fontAsset"]["guid"]==font_id and not q["m_fontStyle"] and not q["m_enableAutoSizing"]
        margin=q["m_margin"]
        assert not any(margin[k] for k in "yzw")
        x,y,w,h=box
        return {"text":q["m_text"],"rect":[x+margin["x"],y,w-margin["x"],h],"anchor":anchor,
                "size":q["m_fontSize"],"style":q["m_fontStyle"],"horizontal":q["m_HorizontalAlignment"],
                "vertical":q["m_VerticalAlignment"],"overflow":q["m_overflowMode"],
                "wrap":q["m_TextWrappingMode"]!=0,"color":q["m_fontColor"]}

    labels=[label(override(base[2915058637345498972],inst,2915058637345498972),rect_in(safe,base[8269007978594452267])),
            label(panel[6956546711977749346],right_title)]
    controls=rect_in(scene,base[2944192064461780042])
    for h,g,t,a in [(4105550822655348061,7229279712121902982,3950320686320582774,"left"),
                    (7796335642725989680,3979155824425089242,8205313523415547342,"right")]:
        # Resolve against the actual component reference if this ID changes.
        children=[base[x["fileID"]] for x in base[h]["m_Children"]]
        boxes=fixed_children(rect_in(controls,base[h]),[dims(r) for r in children],base[g],False)
        for row,box in zip(children,boxes,strict=True):
            if t in base and row["m_GameObject"]==base[t]["m_GameObject"]:
                labels.append(label(override(base[t],inst,t),box,a))
    assert [r["text"] for r in labels[:2]]==["Abilities","Description"]
    assert len(labels)==4
    backings=[image(panel[i],rect_in(box,panel[r])) for box,r,i in (
        (list_box,1703729729,1703729730),(list_box,1921941924,1921941925),
        (description,887420653,887420654),(description,1226898825,1226898826))]
    equip=[]
    for box,r,i,flip in ((list_box,5839702426898105524,5097426463466357787,False),
                         (bar,3798503345055747273,9191692410918609072,False),
                         (bar,2566493430978109446,7975486566981803387,True)):
        definition=panel[r].copy()
        if flip:
            assert definition["m_LocalScale"]==dict(x=-1,y=1,z=1) and definition["m_Pivot"]["x"]==.5
            definition["m_LocalScale"]=dict(x=1,y=1,z=1)
        equip.append(image(panel[i],rect_in(box,definition),flip))

    cat_size=dims(category[65271348870671771])
    group=panel[6131233255611718362]
    assert (group["m_Spacing"],group["m_ChildAlignment"],group["m_ChildControlHeight"])==(8,4,0)
    assert 2*cat_size[1]+group["m_Spacing"]>category_group[3]
    # LayoutGroup.SetChildrenAlongAxis uses a clamped min/preferred blend,
    # with no negative start offset when this axis is smaller than minimum.
    c_icon,c_text=dims(category[2006666368749979419]),dims(category[3022172475002439943])
    assert category[473637049216613506]["m_ChildForceExpandWidth"]==1
    cat_component=category[8528034034496258451]
    cat_button=category[2618705507566220587]
    categories=[]
    for i,kind in enumerate((1,0)):
        box=[category_group[0],category_group[1]+i*(cat_size[1]+group["m_Spacing"]),*cat_size]
        inside=rect_in(box,category[5871650647517770253])
        gap=(inside[2]-c_icon[0]-c_text[0])/2
        ib=[inside[0],inside[1]+(inside[3]-c_icon[1])/2,*c_icon]
        tb=[inside[0]+c_icon[0]+gap,inside[1]+(inside[3]-c_text[1])/2,*c_text]
        categories.append({"type":kind,"rect":box,"icon":ib,"label":label(category[5038416503769030392],tb),
                           "description":receiver["m_activeAbilityDescription" if kind==1 else "m_passiveAbilityDescription"],
                           "term":invalid})

    assert panel[1834533899]["m_Spacing"]==16
    assert [k["fileID"] for k in panel[1834533895]["m_Children"]][1:-1]==[
        4263980732375995394,4618726644880575084,4051064498999485249,3597670259843500099,5364364891431706212]
    generic_size=dims(generic[114492376808643198])
    bar_slots=[]
    for box in fixed_children(bar,[generic_size]*5,panel[1834533899],False):
        bar_slots.append({"rect":box,"icon":rect_in(box,generic[43514262606685224]),
            "background": image(generic[114492376853302420],rect_in(box,generic[114492376853302423])),
            "frame":image(generic[114492376038698944],rect_in(box,generic[114492376038698947]))})

    button, = [r for r in entry.values() if "m_TargetGraphic" in r and r["m_TargetGraphic"]=={"fileID":939711527986824721}]
    assert button["m_Transition"]==1 and button["m_Colors"]["m_ColorMultiplier"]==1
    # Verify LFS bytes and rect without publishing the original image.
    attack=attack_image.read_bytes()
    assert len(attack)==1170 and hashlib.sha256(attack).hexdigest()==ATTACK_HASH
    pointer=raw(ATTACK_IMAGE).decode()
    assert f"oid sha256:{ATTACK_HASH}" in pointer and "size 1170" in pointer
    animation_atlas=yaml.safe_load(raw(ATTACK_IMAGE+".meta"))["TextureImporter"]
    attack_sprite,=[r for r in animation_atlas["spriteSheet"]["sprites"] if str(r["internalID"])=="1173335314239885238"]
    assert attack_sprite["rect"]=={"serializedVersion":2,"x":0,"y":96,"width":32,"height":32}

    icon_ref="Assets/GameData/GameCore/AbilityResources/FormalGas_BasicAttack_IconReference.asset"
    slot_ref=model(icon_ref)[11400000]["m_sprite"]
    assert slot_ref=={"fileID":1173335314239885238,"guid":guid(ATTACK_IMAGE),"type":3}
    icon_guid=guid(icon_ref)
    assert icon_guid in raw("Assets/GameData/GameCore/DatabaseRegistry.asset").decode()

    definitions,configs,timelines,effects = map(table,["exgas_tbability","exgas_tbabilitygamecore",
                                                      "exgas_tbtimelineability","exgas_tbgameplayeffect"])
    abilities={}
    for code in (20001,20010):
        assert configs[code]["IconGuid"]==(icon_guid if code==20001 else "")
        definition=definitions[code]
        assert definition["AbilityLogic"]["$type"]=="ALTimeline"
        timeline=timelines[definition["AbilityLogic"]["Param"]["ID"]]
        damage=[]
        for task in (c for tr in timeline["Tracks"] for c in tr["TaskClips"] if c["Task"]["$type"]=="TaskApplyEffects"):
            for effect_id in task["Task"]["Param"]["IDs"]:
                for key in ("FormalDamage","FormalConditionalDamage"):
                    d=effects[effect_id].get(key)
                    if not d or not (d["FlatDamage"]>0 or abs(d["ScalingFactor"])>.0001):
                        continue
                    assert d["DamageType"]==1
                    parts=[f'{d[k]:g} {fallback[t]}' for k,t in
                        (("FlatDamage","flat_damage"),("ScalingFactor","scaled_damage")) if d[k]]
                    damage.append({"head":fallback["remove_health"],"detail":"+".join(parts)+" "+physical,
                                   "effect_id":effect_id,"frame":task["StartTime"],"kind":key})
        abilities[str(code)]={"name":definition["Name"],"description":definition["Desc"],
            "damage":damage,"icon":None if code==20010 else {"file":"abilities-attack.png","sha256":ATTACK_HASH,
            "sheet_rect":[0,0,32,32]}}
    assert [len(abilities[str(c)]["damage"]) for c in (20001,20010)]==[2,14]
    assert [r["frame"] for r in abilities["20010"]["damage"][::2]]==[1,10,20,30,40,50,60]
    row_sizes=[dims(entry[i]) for i in (939711528114045732,939711527986824718)]
    rows=[]
    for i in range(2):
        row=[viewport[0],viewport[1]+i*(row_height+list_group["m_Spacing"]),row_width,row_height]
        ib,tb=fixed_children(row,row_sizes,entry[939711528066957111],False)
        rows.append({"rect":row,"icon":ib,"label":label(entry[939711527986824721],tb)})
    base_tile=image(base[6380586684605756007],scene)
    assert hashlib.sha256(silver_path.read_bytes()).hexdigest()=="7adcf56d93142ded08ff18196f78fcaaf552411b9a94dc559dac90eb5c91cef1"
    used = "".join(d["description"] + "".join(row["head"]+row["detail"] for row in d["damage"]) for d in abilities.values())
    with TTFont(silver_path) as font:
        chars=font.getBestCmap()
        assert font["head"].unitsPerEm==1900 and (font["hhea"].ascent,font["hhea"].descent)==(1200,-900)
        fallback_metrics={str(n):font["hmtx"].metrics[chars[n]][0] for n in sorted({ord(c) for c in used+"…" if ord(c)>127})}
    return {"schema":1,"source_commit":SOURCE,"pause_action":4,"registration":2,
            "layout":{"content":content,"left":left,"right":right,"viewport":viewport,"labels":labels,
                      "backings":backings,"equip_images":equip,"bar":bar_slots,"categories":categories,
                      "category_sprites":{"selected":s[cat_component["m_selectedSprite"]["fileID"]],
                         "unselected":s[cat_component["m_unselectedSprite"]["fileID"]],
                         **{k:s[v["fileID"]]for k,v in cat_button["m_SpriteState"].items()}},
                      "rows":rows,"description":label(panel[1978025639],rect_in(description,panel[1978025638])),
                      "tile":base_tile,"list_colors":button["m_Colors"]},
            "abilities":abilities,"silver_metrics":fallback_metrics,"dependencies":deps}


if __name__=="__main__":
    cli=argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--repo",required=True,type=Path)
    cli.add_argument("--attack-image",required=True,type=Path)
    cli.add_argument("--silver",required=True,type=Path)
    cli.add_argument("--out",required=True,type=Path)
    args=cli.parse_args()
    result=extract(args.repo,args.attack_image,args.silver)
    args.out.write_text(json.dumps(result,ensure_ascii=False,sort_keys=True,indent=2)+"\n")
