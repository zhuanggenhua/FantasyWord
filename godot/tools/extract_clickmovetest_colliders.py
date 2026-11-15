#!/usr/bin/env python3
"""Read the pinned scene's serialized 2D static shapes for a private probe.

Use the final float outline coordinates, not intermediate integer clip paths.
Do not copy original scene/geometry output into Git. Requires PyYAML.
"""

import argparse
from collections import Counter
import math
from pathlib import Path
import subprocess
import sys

import yaml

sys.dont_write_bytecode = True
from extract_clickmovetest_rules import DOC, SCENE, SOURCE, git, require, write_local, xyz

KINDS = {"GameObject", "Transform", "Rigidbody2D", "BoxCollider2D",
         "TilemapCollider2D", "CompositeCollider2D"}


def get_records(text):
    docs = list(DOC.finditer(text))
    rows = {}
    for i, start in enumerate(docs):
        end = docs[i + 1].start() if i + 1 < len(docs) else len(text)
        content = text[start.end():end]
        name = content.split(":", 1)[0]
        if name not in KINDS:
            continue
        file_id = int(start.group(1))
        require(file_id not in rows, "duplicate Unity component identity")
        rows[file_id] = (name, yaml.safe_load(content)[name])
    return rows


def finite_xy(value):
    point = [float(value[key]) for key in ("x", "y")]
    require(all(map(math.isfinite, point)), "nonfinite static collider coordinate")
    return point


def world_origin(owner, records, transforms):
    at = [0.0, 0.0]
    visited = set()
    while owner not in visited:
        visited.add(owner)
        rolename, game = records[owner]
        require(rolename == "GameObject" and game["m_IsActive"] == 1, "inactive or absent collider owner")
        transform = transforms[owner]
        rotation = transform["m_LocalRotation"]
        require(xyz(transform["m_LocalScale"]) == [1, 1, 1] and xyz(rotation) == [0, 0, 0]
                and abs(rotation["w"]) == 1, "nonidentity collider ancestor basis")
        at = [a + b for a, b in zip(at, finite_xy(transform["m_LocalPosition"]))]
        parent = transform["m_Father"]["fileID"]
        if parent == 0:
            return at
        require(records[parent][0] == "Transform", "non-Transform static collider ancestor")
        owner = records[parent][1]["m_GameObject"]["fileID"]
    raise ValueError("cyclic collider parent chain")


def extract(checkout):
    require(git(checkout, "rev-parse", SOURCE).strip() == SOURCE, "locked source commit not present")
    records = get_records(git(checkout, "show", f"{SOURCE}:{SCENE}"))
    transforms = {f["m_GameObject"]["fileID"]: f for t, f in records.values()
                  if t == "Transform" and "m_LocalPosition" in f}
    static_bodies = {f["m_GameObject"]["fileID"] for t, f in records.values()
                     if t == "Rigidbody2D" and f.get("m_BodyType") == 2 and f.get("m_Simulated") == 1}
    any_bodies = {f["m_GameObject"]["fileID"] for t, f in records.values() if t == "Rigidbody2D"}
    counts = Counter()
    result = []
    contributors, consumed = set(), set()
    for file_id, (kind, f) in records.items():
        if kind not in {"BoxCollider2D", "TilemapCollider2D", "CompositeCollider2D"}:
            continue
        counts[kind] += 1
        owner = f["m_GameObject"]["fileID"]
        layer = records[owner][1]["m_Layer"]
        require(layer == 0 and f["m_Enabled"] == 1 and f["m_IsTrigger"] == 0
                and f["m_UsedByEffector"] == 0, "unsupported locked static collider state")
        require(owner not in any_bodies or owner in static_bodies, "nonstatic collider body")
        at = [a + b for a, b in zip(world_origin(owner, records, transforms), finite_xy(f["m_Offset"]))]
        if kind == "TilemapCollider2D":
            require(f["m_CompositeOperation"] == 1, "standalone Tilemap geometry is not admitted")
            contributors.add(file_id)
            continue
        require(f["m_EdgeRadius"] == 0 and f["m_CompositeOperation"] == 0, "unsupported edge radius or composition")
        row = {"source_file_id": file_id, "layer": layer, "origin": at}
        if kind == "BoxCollider2D":
            size = finite_xy(f["m_Size"])
            require(min(size) > 0, "invalid static box size")
            result.append(dict(row, kind="box", size=size))
        else:
            require(owner in static_bodies and f["m_GeometryType"] == 0
                    and f["m_CompositeGameObject"]["fileID"] == owner, "unsupported composite collider")
            for nested in f["m_ColliderPaths"]:
                collider = nested["m_Collider"]["fileID"]
                nested_kind, nested_props = records[collider]
                require(nested_kind == "TilemapCollider2D" and nested_props["m_GameObject"]["fileID"] == owner
                        and collider not in consumed, "wrong composite input identity")
                consumed.add(collider)
            paths = [[finite_xy(v) for v in p] for p in f["m_CompositePaths"]["m_Paths"]]
            require(paths and all(len(p) >= 3 for p in paths), "missing finalized outlines")
            result.append(dict(row, kind="outlines", paths=paths))
    require(counts == {"BoxCollider2D": 27, "TilemapCollider2D": 8, "CompositeCollider2D": 8}
            and contributors == consumed, "locked collider type counts or composition changed")
    return {"schema": 1, "source_commit": SOURCE, "scene": SCENE, "bodies": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unity-checkout", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        payload = extract(args.unity_checkout)
        write_local(args.output, payload)
    except (ValueError, OSError, KeyError, TypeError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        parser.exit(2, f"ClickMoveTest colliders refused: {exc}\n")
    print(f"ClickMoveTest colliders: {len(payload['bodies'])} static bodies (composite inputs not counted twice)")


if __name__ == "__main__":
    main()
