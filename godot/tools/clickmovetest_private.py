#!/usr/bin/env python3
"""Prepare and launch the normal ClickMoveTest with locked local Unity inputs."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from extract_clickmovetest_abilities import ATTACK_IMAGE
from extract_clickmovetest_pause import ATLAS
from extract_formal_human_animation import SOURCE, read
from extract_workbench_weapons import ART, HUMAN_ART

TOOLS = Path(__file__).resolve().parent
PROJECT = TOOLS.parent
LFS = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([a-f0-9]{64})\nsize (\d+)\n")
ENV = {
    "FORMAL_SURFACE_RULES": "rules.json", "FORMAL_SURFACE_ASSETS": "surface.json",
    "FORMAL_GROUND_LAYERS": "ground", "FORMAL_BURNING_TILE_PNG": "fire-tile.png",
    "FORMAL_PLAYER_DEATH_ANIMATION": "player-animation.json",
    "FORMAL_PLAYER_DEATH_MATERIAL": "player-material.json",
    "FORMAL_PLAYER_TEXTURES": "actor",
    "FORMAL_TRAINER_ATTACK_DEATH_ANIMATION": "trainer-animation.json",
    "FORMAL_TRAINER_ATTACK_DEATH_MATERIAL": "trainer-material.json",
    "FORMAL_TRAINER_ATTACK_TEXTURES": "actor",
    "FORMAL_WATER_REFLECTION_MASK": "water-mask.png", "FORMAL_FLAMETHROWER_CUE": "cue",
    "FORMAL_STATIC_COLLIDERS": "static/colliders.json", "FORMAL_PANEL_SILVER": "Silver.ttf",
    "FORMAL_PANEL_CJK": "NotoSansSC-VF.ttf", "FORMAL_PAUSE_SOURCE": "menu",
    "FORMAL_PLAYER_CLOTH_PNG": "menu/inventory-torso.png", "FORMAL_PLAYER_SPEAR_SOURCE": "spear",
    "FORMAL_PLAYER_EFFECTS_SOURCE": "player-effects.json",
    "FORMAL_TRAINER_EFFECTS_SOURCE": "player-effects.json",
}


def original_inputs():
    plains = "Assets/Art/KrishnaPalacio/MINIFANTASY - Forgotten Plains/Sprites/"
    for layer, names in (("Tileset", ("Tiles", "RedRuleTiles", "TilesShadows")),
                         ("Props", ("Props", "PropsShadow"))):
        for name in names:
            yield f"{plains}{layer}/{name}.png", f"ground/{name}.png"
    yield from {
        "Assets/Art/元素/地表/火焰/32x32火3.png": "fire-tile.png",
        "Assets/Settings/WaterReflection/LakeGrassWaterMask.png": "water-mask.png",
        "Assets/ArtRes/Effects/Elements/Flamethrower/FlamethrowerJet.png": "cue/FlamethrowerJet.png",
        "Assets/GameData/Elements/Audio/Flamethrower_FireSpell03_CC0.ogg": "cue/Flamethrower_FireSpell03_CC0.ogg",
        "Assets/Fonts/Silver.ttf": "Silver.ttf", "Assets/Fonts/NotoSansSC-VF.ttf": "NotoSansSC-VF.ttf",
        ATLAS: "menu/SPS_GUI.png", ATTACK_IMAGE: "menu/abilities-attack.png",
    }.items()
    spear, cloth = "长矛1.png", "精灵-0001.png"
    yield ART + spear, "spear/" + spear
    yield ART + spear, "menu/inventory-weapon.png"
    yield ART + cloth, "menu/inventory-torso.png"
    for name in ("Slash_sword_f.png", "Slash_sword_b.png"):
        yield HUMAN_ART + name, "spear/" + name
    for action in ("Idle", "Walk", "Dmg", "Attack", "SpinDie"):
        name = "Minifantasy_CreaturesHuman" + action
        yield from image_and_meta(HUMAN_ART + name + ".png", "actor/" + name + ".png")
        for kind in ("BodyUV", "HeadUV"):
            tile = f"{name}_{kind}.png"
            yield from image_and_meta("Assets/GameData/EquipmentSystem/GeneratedUV/Human/" + tile,
                                      "actor/uv/" + tile)
    for i, direction in enumerate(("SE", "SW", "NE", "NW"), 1):
        yield from image_and_meta(ART + f"hair{i}.png", f"actor/appearance/hair{direction}.png")
        yield from image_and_meta(ART + f"chin_white{i}.png", f"actor/appearance/beard{direction}.png")
    for i, direction in enumerate(("East", "West"), 1):
        yield from image_and_meta(ART + f"黄色刀疤{i}.png", f"actor/appearance/eyeDecoration{direction}.png")


def image_and_meta(source, dest):
    yield source, dest
    yield source + ".meta", dest + ".meta"


def local_original(repo, source, lfs_storage):
    pinned = read(repo, source)
    pointer = LFS.fullmatch(pinned)
    if pointer is None:
        if pinned.startswith(b"version https://git-lfs.github.com/spec/v1"):
            raise ValueError("无法解析锁定 LFS 指针：" + source)
        return pinned
    oid, size = pointer[1].decode(), int(pointer[2])
    candidates = (repo / source, lfs_storage / "objects" / oid[:2] / oid[2:4] / oid)
    for candidate in candidates:
        if candidate.is_file() and candidate.stat().st_size == size:
            content = candidate.read_bytes()
            if hashlib.sha256(content).hexdigest() == oid:
                return content
    raise ValueError("缺少匹配锁定版本的原 Git LFS 素材：" + source
                     + "。请在已授权的 Unity 检出中先准备原素材，再重试。")


def require_private(directory):
    # Refuse Unity, Godot and any other Git worktree (including linked worktrees).
    base = next(p for p in (directory, *directory.parents) if p.is_dir())
    probe_env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    probe_env["GIT_DISCOVERY_ACROSS_FILESYSTEM"] = "1"
    result = subprocess.run(["git", "-c", "safe.directory=*", "-C", str(base),
                             "rev-parse", "--absolute-git-dir"],
                            capture_output=True, env=probe_env, check=False)
    if result.returncode == 0:
        raise ValueError("私有输入目录必须在 Git 工作树之外。")


def prepare(repo, out, storage):
    require_private(out)
    if out.exists():
        raise ValueError("目标目录已存在；请指定一个新的私有目录。")
    if not out.parent.is_dir():
        raise ValueError("私有输入目录的父目录必须已存在。")
    if storage is None:
        common = subprocess.check_output(["git", "-C", str(repo), "rev-parse",
                                          "--path-format=absolute", "--git-common-dir"],
                                         text=True).strip()
        storage = Path(common) / "lfs"
    with tempfile.TemporaryDirectory(prefix=".clickmovetest-", dir=out.parent) as tmp:
        d = Path(tmp) / "inputs"
        d.mkdir(mode=0o700)
        for source, dest in original_inputs():
            path = d / dest
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(local_original(repo, source, storage))
        build_contracts(repo, d)
        required = [d / v for v in ENV.values()]
        if not all(p.exists() for p in required):
            raise ValueError("私有输入不完整，未生成启动目录。")
        (d / "source-revision.txt").write_text(SOURCE + "\n", encoding="ascii")
        d.rename(out)
    print("私有 ClickMoveTest 启动输入已准备：" + str(out), flush=True)


def build_contracts(repo, d):
    def tool(name, *args):
        subprocess.run([sys.executable, str(TOOLS / (name + ".py")), *map(str, args)], check=True)

    for name, dest in (("rules", "rules.json"), ("elements", "surface.json"),
                       ("ground", "ground/ground.json"), ("colliders", "static/colliders.json")):
        (d / dest).parent.mkdir(parents=True, exist_ok=True)
        tool("extract_clickmovetest_" + name, "--unity-checkout", repo, "--output", d / dest)
    a, m = d / "actor", d / "menu"
    tool("extract_formal_human_animation", "--repo", repo, "--textures", a, "--include-damage",
         "--include-attack", "--include-death", "--output", d / "player-animation.json")
    tool("extract_training_target_animation", "--repo", repo, "--textures", a, "--include-attack",
         "--include-death", "--output", d / "trainer-animation.json")
    for actor, flags in (("player", ("--include-death",)), ("trainer", ("--training-target",))):
        tool("extract_formal_human_material", "--repo", repo, "--human", a, "--generated-uv", a / "uv",
             "--appearance-dir", a / "appearance", "--include-damage", "--include-attack",
             *flags, "--output", d / f"{actor}-material.json")
    tool("extract_clickmovetest_pause", "--repo", repo, "--output", m)
    for name, output, flag in (("settings", "settings-contract.json", "--output"),
                               ("character", "character-contract.json", "--output"),
                               ("character_layout", "character-layout.json", "--output"),
                               ("inventory_layout", "inventory-layout.json", "--out"),
                               ("item_details", "item-details-layout.json", "--out"),
                               ("journal", "journal-layout.json", "--out")):
        tool("extract_clickmovetest_" + name, "--repo", repo, flag, m / output)
    tool("extract_clickmovetest_abilities", "--repo", repo, "--attack-image", m / "abilities-attack.png",
         "--silver", d / "Silver.ttf", "--out", m / "abilities-layout.json")
    tool("extract_workbench_weapons", repo, d / "spear", "--formal-spear")
    tool("extract_formal_human_effects", repo, a, d / "player-effects.json")


def run(directory, godot, editor, smoke):
    require_private(directory)
    stamp = directory / "source-revision.txt"
    if not stamp.is_file() or stamp.read_text(encoding="ascii").strip() != SOURCE:
        raise ValueError("请使用 prepare 生成锁定原版输入。")
    env = {k: v for k, v in os.environ.items() if not k.startswith("FORMAL_")}
    env.update({key: str(directory / val) for key, val in ENV.items()})
    for key in ENV:
        if not Path(env[key]).exists():
            raise ValueError("私有输入缺失：" + ENV[key])
    command = [godot, "--path", str(PROJECT)]
    if editor:
        command.append("--editor")
    if smoke:
        command.extend(("--headless", "--quit-after", "120"))
    return subprocess.call(command, env=env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prep = commands.add_parser("prepare", help="validate hydrated original files and build private inputs")
    prep.add_argument("--unity", type=Path, required=True)
    prep.add_argument("--out", type=Path, required=True)
    prep.add_argument("--lfs-storage", type=Path, help="additional local LFS storage root, no network fetch")
    prep.add_argument("--acknowledge-license", action="store_true", required=True)
    launch = commands.add_parser("run", help="start real Godot project or the editor")
    launch.add_argument("--inputs", type=Path, required=True)
    launch.add_argument("--godot", default="godot")
    mode = launch.add_mutually_exclusive_group()
    mode.add_argument("--editor", action="store_true")
    mode.add_argument("--smoke", action="store_true", help="run the real main scene headless and exit")
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            os.environ["GIT_NO_LAZY_FETCH"] = "1"
            os.environ["GIT_NO_LAZY_FETCH"] = "1"
            prepare(args.unity.resolve(), args.out.resolve(), args.lfs_storage)
            return 0
        return run(args.inputs.resolve(), args.godot, args.editor, args.smoke)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, "ClickMoveTest: " + str(error) + "\n")


if __name__ == "__main__":
    sys.exit(main())
