#!/usr/bin/env python3
"""Extract only the pinned ClickMoveTest shared Item Details contract."""
import argparse
import hashlib
import json
from pathlib import Path

import yaml

from extract_clickmovetest_pause import ATLAS, FONT, ROOT, SOURCE, docs, read, rect_in

PREFAB = "Assets/Prefabs/UI/Overlay/Item Details.prefab"


def extract(repo):
    hashes = {}

    def raw(path):
        data = read(repo, path)
        hashes[path] = hashlib.sha256(data).hexdigest()
        return data

    def guid(path):
        return yaml.safe_load(raw(path + ".meta"))["guid"]

    main = {i: row for i, (_, row) in docs(raw(ROOT)).items()}
    registration = main[8859138291591509816]
    assert registration["m_SourcePrefab"]["guid"] == guid(PREFAB)
    assert registration["m_Modification"]["m_TransformParent"]["fileID"] == 6839323979664588595
    siblings = [child["fileID"] for child in main[6839323979664588595]["m_Children"]]
    assert siblings.index(498946577117702277) < siblings.index(2417890558609779387)
    assert any(m["target"]["fileID"] == 8943416664039111349 and
               m["propertyPath"] == "m_IsActive" and str(m["value"]) == "0"
               for m in registration["m_Modification"]["m_Modifications"])
    rows = {i: row for i, (_, row) in docs(raw(PREFAB)).items()}
    root = rect_in([0, 0, 1920, 1080], rows[8943416662869155773])
    assert root == [0, 0, 1920, 1080]
    body = rect_in(root, rows[8943416664039111350])
    header = rect_in(body, rows[8943416663000155542])
    inner = rect_in(body, rows[8943416663991029157])
    atlas_id = guid(ATLAS)
    atlas = yaml.safe_load(raw(ATLAS + ".meta"))["TextureImporter"]
    assert atlas["spritePixelsToUnits"] == 16
    sprites = {s["internalID"]: {"rect":s["rect"], "border":s["border"]}
               for s in atlas["spriteSheet"]["sprites"]}

    def background(box, field, kind):
        row = rows[field]
        assert row["m_Sprite"] == {"fileID":0} and row["m_Type"] == kind and row["m_RaycastTarget"]
        return {"rect":box, "color":row["m_Color"]}

    def frame(parent, rect, field):
        row = rows[field]
        ref = row["m_Sprite"]
        assert row["m_Type"] == 1 and row["m_RaycastTarget"] and row["m_FillCenter"]
        assert ref["guid"] == atlas_id and row["m_PixelsPerUnitMultiplier"] == 1
        return {"rect":rect_in(parent,rows[rect]), "sprite":sprites[ref["fileID"]]}

    font_id = guid(FONT)

    def label(parent, rect, field, overflow):
        row = rows[field]
        assert row["m_fontAsset"]["guid"] == font_id and row["m_fontSize"] == 48
        assert row["m_RaycastTarget"] and row.get("m_TextWrappingMode",row.get("m_enableWordWrapping")) == 1
        assert row["m_overflowMode"] == overflow and row["m_fontStyle"] == row["m_enableAutoSizing"] == 0
        assert not any(row["m_margin"].values())
        return {"rect":rect_in(parent,rows[rect]),"size":row["m_fontSize"],
                "horizontal":row["m_HorizontalAlignment"],"vertical":row["m_VerticalAlignment"],
                "style":row["m_fontStyle"],"color":row["m_fontColor"],"overflow":overflow}

    items = []
    for kind, name, icon, file in [(0,"长矛","长矛1","weapon"),(2,"基础布衣","精灵-0001","torso")]:
        path = f"Assets/Database/Items/Equipment/{name}.asset"
        item = docs(raw(path))[11400000][1]
        image = f"Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/{icon}.png"
        assert item["m_type"] == kind and int(item["m_bonusStats"]["m_values"]) == 0
        assert item["m_icon"]["guid"] == guid(image)
        pointer = dict(line.split(" ",1) for line in raw(image).decode().splitlines())
        oid = pointer["oid"].removeprefix("sha256:")
        items.append({"type":kind,"name":item["m_displayName"],"description":item["m_description"],
                      "icon_file":f"inventory-{file}.png","icon_sha256":oid})
    return {"schema":1,"source_commit":SOURCE,
            "body":background(body,8943416663663610817,1),
            "body_frame":frame(body,8943416662666595767,8943416662666595760),
            "header":background(header,8943416662841112386,2),
            "header_frame":frame(header,8943416662986545729,8943416662986545730),
            "icon":rect_in(header,rows[8943416662806617161]),
            "name":label(header,8943416663546739942,8943416663546739943,1),
            "description":label(inner,8943416662684927163,8943416662684927172,0),
            "items":items,"dependencies":hashes}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo",required=True,type=Path)
    parser.add_argument("--out",required=True,type=Path)
    args = parser.parse_args()
    args.out.write_text(json.dumps(extract(args.repo), ensure_ascii=False, sort_keys=True, indent=2)+"\n")
