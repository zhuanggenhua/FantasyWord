"""Extract locked Goblin/Orc workbench contracts into a private directory, never for Git publication."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
from PIL import Image
import subprocess

from extract_formal_human_animation import SOURCE, h, parse, read

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--unity", type=Path, required=True, help="pinned Unity Git checkout with original objects")
parser.add_argument("--out", type=Path, required=True, help="private output directory (outside either project)")
parser.add_argument("--lfs-dir", type=Path, help="optional authorized LFS files named by SHA-256")
args = parser.parse_args()
repo = args.unity.resolve()
base = args.out.resolve()
if base.is_relative_to(repo) or base.is_relative_to(Path(__file__).resolve().parents[2]):
    parser.error("output must be outside both tracked projects")
base.mkdir(parents=True, exist_ok=True)

root = "Assets/GameData/EquipmentSystem/"
dir_keys = ("southEast", "southWest", "northEast", "northWest")
short_keys = ("SE", "SW", "NE", "NW")
choices = {
    "Goblin": ("地精", "SpinDie", "Minifantasy_CreaturesGoblinIdle", "Minifantasy_CreaturesGoblinSpinDie"),
    "Orc": ("兽人", "Die", "Orc_Idle", "Orc_Die"),
}

def git(*args):
    return subprocess.check_output(["git", "-C", str(repo), *args])

files = git("-c","core.quotePath=false","ls-tree","-r","--name-only",SOURCE).decode().splitlines()
lfs = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir").decode().strip()) / "lfs/objects"

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def asset(path):
    return parse(read(repo,path))["MonoBehaviour"]

def meta(path):
    return parse(read(repo,path+".meta"))

expected_ids = {}
for rel in files:
    if not rel.endswith(".png.meta") or not any(race in rel for race in choices): continue
    guid = re.search(rb"^guid: ([0-9a-f]{32})$", read(repo,rel), re.M)
    if guid: expected_ids.setdefault(guid.group(1).decode(), []).append(rel[:-5])

def png(expected_guid, out):
    candidates = expected_ids.get(expected_guid,[])
    filename = Path(candidates[0]).name if candidates else ""
    assert len(candidates)==1, candidates
    source = candidates[0]
    lock = read(repo,source)
    if lock.startswith(b"version https://git-lfs.github.com/spec/v1"):
        pointer = lock.decode().splitlines()
        assert pointer[0]=="version https://git-lfs.github.com/spec/v1"
        digest = pointer[1].split(":",1)[1]
        original = lfs/digest[:2]/digest[2:4]/digest
        staged = (args.lfs_dir if args.lfs_dir else base/"lfs")/digest
        if not original.exists() and not staged.exists():
            missing[digest] = {"path":source,"size":int(pointer[2].split()[1])}
            return {"file":filename,"path":source,"missing":True}, {}
        actual = (original if original.exists() else staged).read_bytes()
        assert sha(actual)==digest and pointer[2]==f"size {len(actual)}"
    else:
        actual = lock
        assert actual[:8]==b"\x89PNG\r\n\x1a\n"
    importer = meta(source)["TextureImporter"]
    settings = importer["textureSettings"]
    assert settings["filterMode"]==0, (source, settings)
    raw_meta = read(repo,source+".meta")
    (out/filename).write_bytes(actual)
    (out/(filename+".meta")).write_bytes(raw_meta)
    return {"file":filename,"path":source,"guid":expected_guid,"sha256":sha(actual),
            "size":list(struct.unpack(">II",actual[16:24])),"meta_sha256":sha(raw_meta),
            "wrap":settings["wrapU"],"sRGB":importer["mipmaps"]["sRGBTexture"]}, importer

catalog_path = root+"Data/Workbench/换装工作台目录.asset"
scene_path = "Assets/Scenes/EquipmentSystemDemo.unity"
assert f'catalog: {{fileID: 11400000, guid: {meta(catalog_path)["guid"]}, type: 2}}' in read(repo,scene_path).decode()
catalog = asset(catalog_path)["characters"]
assert [v["displayName"] for v in catalog]==["人类","矮人","精灵","地精","兽人"]
appearance_path = root+"Appearance/绿皮外观.asset"
appearance = asset(appearance_path)
assert len(appearance["skinSrcColors"])==len(appearance["skinDstColors"])==5
assert all(appearance[f"{layer}{side}"]["fileID"]==0 for layer in ("hair","beard","faceAccessory") for side in short_keys)
assert all(appearance[f"eyeDecoration{side}"]["fileID"]==0 for side in ("East","West"))
db_path = root+"AnimationType/AnimationTypeDatabase.asset"
db_guids = [row["guid"] for row in asset(db_path)["_items"]]
assert len(db_guids)==28
result = {"source_commit":SOURCE,"scope":"private_nonhuman_workbench_validation","catalog_order":[v["displayName"] for v in catalog],
          "base_appearance":{k:appearance[k] for k in ("skinSrcColors","skinDstColors","leftEyeColor","rightEyeColor")},
          "appearance_sha256":sha(read(repo,appearance_path)),"characters":{}}
import yaml
controller_path = root+"Animations/换装共享动画状态机.controller"
raw_controller = read(repo,controller_path)
controller_yaml = re.sub(r"^%.*\n", "", raw_controller.decode(), flags=re.M)
controller_yaml = re.sub(r"^--- !u!\d+ &[-\d]+", "---", controller_yaml, flags=re.M)
states = {node["AnimatorState"]["m_Name"]:node["AnimatorState"] for node in yaml.safe_load_all(controller_yaml)
          if node and "AnimatorState" in node}
missing={}
errors={}
for race,(name,terminal,idle_atlas,terminal_atlas) in choices.items():
    out = base/race
    out.mkdir(exist_ok=True)
    index, = [i for i,row in enumerate(catalog) if row["displayName"]==name]
    option = catalog[index]
    assert option["appearance"]["guid"]==meta(appearance_path)["guid"]
    assert option["defaultEquipment"]==catalog[0]["defaultEquipment"] and len(option["defaultEquipment"])==1
    frame_path = root+f"FrameData/{name}帧数据.asset"
    assert option["frameData"]["guid"]==meta(frame_path)["guid"]
    raw_frames = read(repo,frame_path)
    assert f'animDatabase: {{fileID: 11400000, guid: {meta(db_path)["guid"]}, type: 2}}' in raw_frames.decode()
    blocks = raw_frames.decode().split("\n  - animationType: ")[1:]
    assert len(blocks)==14
    libs = []
    for side,short in zip(dir_keys,short_keys):
        path=root+f"Animations/SpriteLibraries/{name}_{short}动画精灵库.asset"
        assert option["animationLibraries"][side]["guid"]==meta(path)["guid"]
        libs.append(asset(path)["m_Labels"])
    names = [e["m_Name"] for e in libs[0]]
    assert len(names)==14 and len(set(names))==14 and "Idle" in names and terminal in names
    assert all({e["m_Name"] for e in lib}==set(names) for lib in libs)
    assert all(any(meta(root+f"AnimationType/{key}.asset")["guid"] in line.splitlines()[0] for line in blocks) for key in names)
    data = {"label":name,"catalog_index":index,"default_equipment_guid":option["defaultEquipment"][0]["guid"],
            "original_exact_actions":names,"frame_sha256":sha(raw_frames),"actions":{}}
    result["characters"][race]=data
    for key in names:
        try:
            action_guid = meta(root+f"AnimationType/{key}.asset")["guid"]
            assert db_guids.count(action_guid)==1
            block, = [r for r in blocks if action_guid in r.splitlines()[0]]
            keep = ("    spritesheet:", "    frameSize:", "    framesPerRow:", "    rowCount:", "    bodyUVMap:", "    headUVMap:",
                    "    frames:", "    - frameIndex:", "      rowIndex:", "      anchors:",
                    "      bodyRegions:", "      - part:", "        spriteFacing:", "        variant:",
                    "      leftEyeClosed:", "      rightEyeClosed:")
            frame = parse(("- animationType: "+block.splitlines()[0]+"\n"+"\n".join(
                line[2:] for line in block.splitlines()[1:] if line.startswith(keep))).encode())[0]
            count,rows=frame["framesPerRow"],frame["rowCount"]
            assert frame["frameSize"]=={"x":32,"y":32}
            assert len(frame["frames"])==rows*count
            body, imp = png(frame["spritesheet"]["guid"],out)
            if body.get("missing"): continue
            assert body["size"]==[count*32,rows*32] and body["wrap"]==1
            assert imp["spritePixelsToUnits"]==8 and imp["spriteMeshType"]==1
            region_by_id = {f["internalID"]:f for f in imp["spriteSheet"]["sprites"]}
            directions = []
            for lib in libs:
                cat, = [v for v in lib if v["m_Name"]==key]
                assert cat["m_Hash"]==h(key)
                packed = []
                for index,item in enumerate(cat["m_CategoryList"]):
                    ref = item["m_Sprite"]
                    assert str(item["m_Name"])==str(index) and item["m_Hash"]==h(index) and ref["guid"]==body["guid"]
                    sprite = region_by_id[ref["fileID"]]
                    assert sprite["pivot"]=={"x":.5,"y":.5}
                    rect = [sprite["rect"][n] for n in ("x","y","width","height")]
                    assert rect[2:]==[32,32]
                    packed.append({"file_id":str(ref["fileID"]),"rect":rect,"texture":body["file"]})
                directions.append(packed)
            assert all(len(group)==count and [f["rect"][0] for f in group]==list(range(0,count*32,32)) for group in directions)
            if rows==1: assert directions==[directions[0]]*4 and all(f["rect"][1]==0 for f in directions[0])
            else: assert all(0<=f["rect"][1]<32*rows for group in directions for f in group)
            clip_path = root+f"Animations/SharedClips/{key}.anim"
            clip = parse(read(repo,clip_path))["AnimationClip"]
            assert states[key]["m_Motion"]["guid"]==meta(clip_path)["guid"]
            assert states[key]["m_Speed"]==1 and clip["m_Events"]==[]
            settings = clip["m_AnimationClipSettings"]
            curves = clip["m_FloatCurves"]
            assert settings["m_StartTime"]==0 and clip["m_SampleRate"]==8 and len(curves)==1 and curves[0]["attribute"]=="m_SpriteHash"
            keys = curves[0]["curve"]["m_Curve"]
            hashed = {h(f"{key}_{i}"):i for i in range(count)}
            labels = [hashed[struct.unpack("<I",struct.pack("<f",k["value"]))[0]] for k in keys]

            uv = {}
            for channel in ("Body","Head"):
                spec,_ = png(frame[channel.lower()+"UVMap"]["guid"],out)
                uv[channel.lower()] = spec
                if spec.get("missing"): continue
                assert spec["size"]==body["size"] and not spec["sRGB"]
                spec["all_zero"] = Image.open(out / spec["file"]).convert("RGBA").getbbox(alpha_only=False) is None
                uv[channel.lower()] = spec
            if any(spec.get("missing") for spec in uv.values()): continue
            assert all(v["all_zero"] and v["wrap"]==0 for v in uv.values()), "needs separate authored base composition"
            data["actions"][key] = {"event_names":[event.get("functionName") for event in clip["m_Events"]],"duration":settings["m_StopTime"],"loop":bool(settings["m_LoopTime"]),
                "times":[k["time"] for k in keys],"labels":labels,"directions":directions,"body":body,"uv":uv}
        except (AssertionError, KeyError, ValueError) as exc:
            import traceback
            errors[f"{race}:{key}"] = traceback.format_exception_only(type(exc),exc)[-1].strip() + " (line " + str(exc.__traceback__.tb_lineno) + ")"
    print(race, names, [(a,s["duration"],s["body"]["size"],[(v["wrap"],v["all_zero"]) for v in s["uv"].values()],s["event_names"]) for a,s in data["actions"].items()])
(base/"private-nonhuman-action-audit.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")

(base/"missing.json").write_text(json.dumps(missing,ensure_ascii=False,indent=2)+"\n")
print("missing unique",len(missing),"errors",errors)

if missing or errors or any(len(c["actions"]) != 14 for c in result["characters"].values()):
    raise SystemExit("Original frame/clip/texture checks incomplete; private contract is not eligible.")
