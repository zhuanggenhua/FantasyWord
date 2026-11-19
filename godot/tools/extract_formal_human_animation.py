#!/usr/bin/env python3
"""从锁定 Unity Git 对象导出私有 Human Idle/Walk（可显式附加 Dmg/ChargedAttack/Attack）精灵合同，不复制原始资产。"""
import argparse, hashlib, json, re, struct, subprocess, zlib
from pathlib import Path
import yaml
SOURCE = "31629d53a110dd4c87d4c85e6ad5a387fbafb931"
ROOT = "Assets/GameData/EquipmentSystem/Animations/"
def read(repo, path):
    return subprocess.check_output(["git", "-C", str(repo), "show", f"{SOURCE}:{path}"])
def parse(raw):
    text = re.sub(r"^%.*\n", "", raw.decode(), flags=re.M)
    text = re.sub(r"^--- !u!\d+ &[-\d]+", "---", text, flags=re.M)
    return yaml.safe_load(text)
def h(value): return zlib.crc32(str(value).encode()) & 0x3fffffff
def extract(repo, textures, include_damage=False, include_charged=False, include_attack=False, include_death=False):
    paths = subprocess.check_output(["git", "-c", "core.quotepath=false", "-C", str(repo), "ls-tree", "-r", "--name-only", SOURCE], text=True).splitlines()
    sources = {}
    def source(path):
        raw = read(repo,path); sources[path] = hashlib.sha256(raw).hexdigest(); return parse(raw)
    # 控制器有多个 YAML 文档；仅验证所需状态和对应片段 GUID，没有猜测其它状态。
    raw = read(repo,ROOT + "换装共享动画状态机.controller")
    sources[ROOT+"换装共享动画状态机.controller"] = hashlib.sha256(raw).hexdigest()
    states = []
    text = re.sub(r"^%.*\n", "", raw.decode(), flags=re.M)
    text = re.sub(r"^--- !u!\d+ &[-\d]+", "---", text, flags=re.M)
    for doc in yaml.safe_load_all(text):
        if "AnimatorState" in doc: states.append(doc["AnimatorState"])
    libs = [source(ROOT+f"SpriteLibraries/人类_{d}动画精灵库.asset")["MonoBehaviour"] for d in ("SE","SW","NE","NW")]
    actions = {}; textures_out = {}
    for action in ("Idle","Walk") + (("Dmg",) if include_damage else ()) + (("ChargedAttack",) if include_charged else ()) + (("Attack",) if include_attack else ()) + (("SpinDie",) if include_death else ()):
        clip_path = ROOT + f"SharedClips/{action}.anim"
        clip = source(clip_path)["AnimationClip"]
        clip_guid = source(clip_path+".meta")["guid"]
        matches = [s for s in states if s["m_Name"] == action]
        assert len(matches)==1 and matches[0]["m_Motion"]["guid"] == clip_guid
        if action in ("Dmg", "ChargedAttack", "Attack", "SpinDie"):
            state = matches[0]
            assert state["m_Speed"] == 1 and state["m_CycleOffset"] == 0
            assert state["m_Transitions"] == [] and state["m_StateMachineBehaviours"] == []
            assert all(state[k] == 0 for k in ("m_SpeedParameterActive", "m_CycleOffsetParameterActive", "m_TimeParameterActive"))
            settings = clip["m_AnimationClipSettings"]
            assert settings["m_StopTime"] == {"ChargedAttack":0.75,"SpinDie":1.5}.get(action,0.5) and settings["m_LoopTime"] == 0
        curves = clip["m_FloatCurves"]
        assert len(curves)==1 and curves[0]["attribute"] == "m_SpriteHash" and curves[0]["path"] in ("", None)
        keys = curves[0]["curve"]["m_Curve"]
        directions=[]; expected_hashes=None
        for lib in libs:
            cat = next(c for c in lib["m_Labels"] if c["m_Name"]==action)
            assert cat["m_Hash"]==h(action)
            items = cat["m_CategoryList"]; assert [str(e["m_Name"]) for e in items] == [str(i) for i in range(len(items))]
            frames=[]
            for item in items:
                label=int(item["m_Name"]); assert item["m_Hash"]==h(label)
                ref=item["m_Sprite"]
                name=f"Minifantasy_CreaturesHuman{action}.png"
                meta_file=textures/(name+".meta")
                meta_raw=meta_file.read_bytes(); meta=parse(meta_raw)
                assert meta["guid"] == ref["guid"]
                meta_paths=[p for p in paths if p.endswith("/"+name+".meta") and read(repo,p)==meta_raw]
                assert len(meta_paths)==1, "必须提供原提交中的逐字 meta"
                meta_path=meta_paths[0]; sources[meta_path]=hashlib.sha256(meta_raw).hexdigest()
                png_path=meta_path[:-5]; png=(textures/name).read_bytes()
                pointer=read(repo,png_path).decode()
                sha=hashlib.sha256(png).hexdigest()
                assert f"oid sha256:{sha}" in pointer and f"size {len(png)}" in pointer
                tex=meta["TextureImporter"]
                assert tex["spritePixelsToUnits"]==8 and tex["spriteMeshType"]==0 and tex["textureSettings"]["filterMode"]==0
                records=[x for x in tex["spriteSheet"]["sprites"] if x["internalID"] == ref["fileID"]]
                assert len(records)==1
                frame=records[0]; rect=frame["rect"]; pivot=frame["pivot"]
                assert rect["width"]==32 and rect["height"]==32 and pivot=={"x":.5,"y":.5}
                frames.append({"name":frame["name"],"file_id":str(ref["fileID"]),"rect":[rect[k] for k in ("x","y","width","height")],"texture":name})
                width,height=struct.unpack(">II",png[16:24])
                textures_out[name]={"sha256":sha,"size":[width,height],"pixels_per_unit":8}
            hashes={h(f"{action}_{i}"):i for i in range(len(items))}
            assert len(hashes)==len(items)
            if expected_hashes is None: expected_hashes=hashes
            else: assert hashes==expected_hashes
            directions.append(frames)
        labels=[]
        for key in keys:
            assert str(key["inSlope"])=="Infinity" and str(key["outSlope"])=="Infinity"
            bits=struct.unpack("<I",struct.pack("<f",key["value"]))[0]
            assert bits in expected_hashes
            labels.append(expected_hashes[bits])
        if action == "ChargedAttack":
            assert [k["time"] for k in keys] == [i / 8 for i in range(7)]
            assert labels == [0, 1, 2, 3, 4, 5, 5]
            assert all(len(frames) == 6 for frames in directions)
        if action == "Attack":
            assert [k["time"] for k in keys] == [i / 8 for i in range(5)]
            assert labels == [0, 1, 2, 3, 3]
            assert all(len(frames) == 4 for frames in directions)
        if action == "SpinDie":
            assert [k["time"] for k in keys] == [i / 8 for i in range(13)]
            assert labels == [*range(12), 11]
            assert all(len(frames) == 12 for frames in directions)
        settings=clip["m_AnimationClipSettings"]
        assert settings["m_StartTime"]==0 and clip["m_SampleRate"]==8
        actions[action]={"duration":settings["m_StopTime"],"loop":bool(settings["m_LoopTime"]),"times":[k["time"] for k in keys],"labels":labels,"directions":directions}
    return {"schema":1,"source_commit":SOURCE,"actions":actions,"textures":textures_out,"source_sha256":sources}
if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__); p.add_argument("--repo",type=Path,required=True);p.add_argument("--textures",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    p.add_argument("--include-damage",action="store_true",help="同时核实原 Dmg 四向非循环片段")
    p.add_argument("--include-charged",action="store_true",help="同时核实原 ChargedAttack 四向非循环片段")
    p.add_argument("--include-attack",action="store_true",help="同时核实原 Attack 四向非循环片段")
    p.add_argument("--include-death",action="store_true",help="同时核实原 SpinDie 非循环片段")
    a=p.parse_args(); result=extract(a.repo,a.textures,a.include_damage,a.include_charged,a.include_attack,a.include_death); a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("Human 私有合同：四向来源、所有标签和 PNG 哈希已核验。")
