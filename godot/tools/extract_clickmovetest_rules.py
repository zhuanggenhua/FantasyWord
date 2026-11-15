#!/usr/bin/env python3
"""Extract only locked ClickMoveTest rule values into a private local fixture.

No sprites, assets, Unity scene files, rendering data or surface-cover data
are written. The input is the locked Git object, never a modified working file.
Requires PyYAML. Output must be a new file outside Git working trees.
"""

import argparse
from collections import Counter
import json
import math
import os
from pathlib import Path
import re
import subprocess

import yaml

SOURCE = "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
SCENE = "Assets/Scenes/ClickMoveTest.unity"
RULE_TILEMAP = 1361196487
DOC = re.compile(r"(?m)^--- !u!\d+ &(-?\d+)(?: stripped)?\s*\n")
TILE_CLASS = "FantasyWord.GameCore::FantasyWord.GameCore.TerrainNavigationTile"
TILE_GUID = "33c93e06b5c97fb429cabe86066ec416"
ASSET_ROOT = "Assets/Scenes/ClickMoveTestMaterials/TerrainNavigation/"


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def git(checkout, *args):
    return subprocess.check_output(["git", "-C", str(checkout), *args], stderr=subprocess.PIPE).decode("utf-8")


def get_document(text, file_id, typename):
    docs = list(DOC.finditer(text))
    matches = [i for i, doc in enumerate(docs) if int(doc.group(1)) == file_id]
    require(len(matches) == 1, f"missing or duplicated Unity document {file_id}")
    i = matches[0]
    end = docs[i + 1].start() if i + 1 < len(docs) else len(text)
    content = yaml.safe_load(text[docs[i].end():end])
    require(isinstance(content, dict) and set(content) == {typename}, f"unexpected Unity document {file_id}")
    return content[typename]


def xyz(value):
    return [value[key] for key in ("x", "y", "z")]


def expect_rectangular_grid(scene):
    config = get_document(scene, 1148507052, "MonoBehaviour")
    require(config["m_ruleTilemap"]["fileID"] == RULE_TILEMAP
            and not config["m_layerSources"] and not config["m_transitionLinks"],
            "not the legacy default navigation layer")
    grid = get_document(scene, 1148507051, "Grid")
    require(xyz(grid["m_CellSize"]) == [1, 1, 1] and xyz(grid["m_CellGap"]) == [0, 0, 0]
            and grid["m_CellLayout"] == 0 and grid["m_CellSwizzle"] == 0,
            "not the locked rectangular unit grid")
    for node, parent in ((1361196485, 1148507050), (1148507050, 6951707),
                         (6951707, 900000102), (900000102, 0)):
        transform = get_document(scene, node, "Transform")
        rotation = transform["m_LocalRotation"]
        require(xyz(transform["m_LocalPosition"]) == [0, 0, 0]
                and xyz(transform["m_LocalScale"]) == [1, 1, 1]
                and xyz(rotation) == [0, 0, 0] and abs(rotation["w"]) == 1
                and transform["m_Father"]["fileID"] == parent, "nonidentity rule grid transform chain")
    return int(config["m_nearestWalkableSearchRadius"])


def resolve_rule(checkout, ref):
    guid = ref["guid"]
    require(ref["fileID"] == 11400000 and re.fullmatch(r"[0-9a-f]{32}", guid), "invalid rule asset reference")
    result = git(checkout, "grep", "-zl", f"^guid: {guid}$", SOURCE, "--", "*.asset.meta").strip("\0")
    rows = result.split("\0")
    require(len(rows) == 1 and rows[0].startswith(f"{SOURCE}:{ASSET_ROOT}"), "rule asset reference is not unique")
    path = rows[0].split(":", 1)[1].removesuffix(".meta")
    tile = get_document(git(checkout, "show", f"{SOURCE}:{path}"), 11400000, "MonoBehaviour")
    require(tile["m_EditorClassIdentifier"] == TILE_CLASS and tile["m_Script"]["guid"] == TILE_GUID,
            "rule asset has wrong class identity")
    cost = float(tile["m_traversalCost"])
    ramp = tile.get("m_rampDirection", 0)  # Source C# field initializer is None (0).
    require(math.isfinite(cost) and tile["m_walkable"] in (0, 1)
            and tile["m_transitionKind"] in (0, 1, 2)
            and ramp in range(5)
            and tile["m_surfaceKind"] in range(7), "unsupported rule values")
    return {"walkable": bool(tile["m_walkable"]), "elevation": int(tile["m_elevation"]),
            "transition": int(tile["m_transitionKind"]), "ramp": int(ramp),
            "surface": int(tile["m_surfaceKind"]), "cost": cost}


def extract(checkout):
    require(git(checkout, "rev-parse", SOURCE).strip() == SOURCE, "locked source commit not present")
    scene = git(checkout, "show", f"{SOURCE}:{SCENE}")
    radius = expect_rectangular_grid(scene)
    tilemap = get_document(scene, RULE_TILEMAP, "Tilemap")
    require(xyz(tilemap["m_TileAnchor"]) == [0.5, 0.5, 0] and tilemap["m_GameObject"]["fileID"] == 1361196484,
            "unexpected rule Tilemap anchor or owner")
    origin, size = xyz(tilemap["m_Origin"]), xyz(tilemap["m_Size"])
    require(origin[2] == 0 and size[2] == 1, "only the locked planar rule layer is supported")
    references = tilemap["m_TileAssetArray"]
    rules = [resolve_rule(checkout, item["m_Data"]) for item in references]
    refs = Counter()
    occupied = set()
    rows = []
    for tile in tilemap["m_Tiles"]:
        cell = xyz(tile["first"])
        index = tile["second"]["m_TileIndex"]
        require(0 <= index < len(rules) and tuple(cell) not in occupied
                and all(o <= c < o + span for o, c, span in zip(origin, cell, size)), "invalid tile cell or index")
        occupied.add(tuple(cell))
        refs[index] += 1
        rows.append({"cell": cell, **rules[index]})
    require(all(refs[index] == item["m_RefCount"] for index, item in enumerate(references)), "tile reference counts differ")
    rows.sort(key=lambda row: (row["cell"][1], row["cell"][0]))
    return {"schema": 1, "source_commit": SOURCE, "rule_tilemap": RULE_TILEMAP,
            "origin": origin, "size": size, "nearest_radius": radius,
            "rule_count": len(rules), "rows": rows}


def write_local(path, payload):
    path = path.absolute()
    parent = path.parent.resolve(strict=True)
    probe = subprocess.run(["git", "-C", str(parent), "rev-parse", "--show-toplevel"], capture_output=True)
    require(probe.returncode != 0, "private rule fixture output must be outside Git working trees")
    with os.fdopen(os.open(parent / path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600),
                   "w", encoding="utf-8") as file:
        json.dump(payload, file, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
        file.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unity-checkout", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        payload = extract(args.unity_checkout)
        write_local(args.output, payload)
    except (ValueError, OSError, KeyError, TypeError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        parser.exit(2, f"ClickMoveTest rules refused: {exc}\n")
    print(f"ClickMoveTest rules: {len(payload['rows'])} cells, {payload['rule_count']} original rules")


if __name__ == "__main__":
    main()
