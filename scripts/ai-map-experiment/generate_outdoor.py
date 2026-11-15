"""离线野外地图实验：读取 MiniFantasy 原始切片和示例组合，输出 Forge 地图数据。

布局 JSON 是本实验的作者输入；图集、碰撞、预览和导出均为派生物。
不修改 Unity 资源，不模拟 InteliMap，不声明通过 Unity 运行态验收。
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from functools import lru_cache
import hashlib
import json
import math
import os
from pathlib import Path
import random
import re
import struct
import subprocess
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw
import yaml

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "Assets/Art/KrishnaPalacio/MINIFANTASY - Forgotten Plains"
SCENE = PACK / "Scenes/Demo - Forgotten Plains.unity"
LOADER = getattr(yaml, "CSafeLoader", yaml.SafeLoader)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ensure_forge(root):
    """只获取锁定版本的外部 CLI 文件；缓存或下载内容哈希不符时停止。"""
    lock = json.loads(Path(__file__).with_name("forge-cli-lock.json").read_text())
    for entry in lock["files"]:
        target = root / entry["path"]
        if not target.exists():
            url = ("https://raw.githubusercontent.com/0x0funky/agent-sprite-forge/"
                   + lock["revision"] + "/skills/generate2dmap/" + entry["path"])
            data = urllib.request.urlopen(url, timeout=30).read()
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                raise ValueError(f"外部 CLI 下载校验失败：{entry['path']}")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        if sha(target) != entry["sha256"]:
            raise ValueError(f"外部 CLI 缓存已改变：{target}")


def run_checks(output, forge_root, node_modules):
    """运行原 skill 的独立检查和导出；严格模式下的警告或失败直接中断。"""
    environment = os.environ.copy()
    if node_modules:
        environment["NODE_PATH"] = str(node_modules)
    scripts = forge_root / "scripts"
    bundle = str(output / "map-bundle.json")
    commands = [
        ["map_bundle.py", "validate", "--bundle", bundle, "--report", str(output/"bundle-report.json")],
        ["map_nav.py", "check", "--bundle", bundle, "--output-dir", str(output/"nav")],
        ["build_scene_preview.py", "--bundle", bundle, "--output-dir", str(output/"preview"),
         "--zoom", "3", "--verify", "--strict", "--verify-timeout", "90"],
        ["export_tiled.py", "export", "--bundle", bundle, "--output-dir", str(output/"tiled"),
         "--embedded-variant"]
    ]
    for name, *arguments in commands:
        subprocess.run([sys.executable, "-X", "utf8", str(scripts/name), *arguments],
                       cwd=ROOT, env=environment, check=True)


@lru_cache(maxsize=None)
def unity_documents(path):
    """只读取 Unity YAML；保留对象 ID，并防止十六进制邻接表被 YAML 当作整数。"""
    source = path.read_text(encoding="utf-8-sig")
    source = re.sub(r"^%.*\n", "", source, flags=re.M)
    source = re.sub(r"^--- !u!(\d+) &(-?\d+)(?: stripped)?$",
                    r"---\n__file_id: \2\n__class_id: \1", source, flags=re.M)
    source = re.sub(r"(m_Neighbors: )([0-9a-fA-F]+)", r'\1"\2"', source)
    return list(yaml.load_all(source, Loader=LOADER))


class SourceArt:
    """以原始 .meta 中的 GUID、fileID、矩形和 pivot 为切片真相源。"""
    def __init__(self, pack=PACK, scene=SCENE):
        self.sprites = {}
        self.named = {}
        self.inputs = {scene}
        for meta in sorted((pack / "Sprites").rglob("*.png.meta")):
            doc = yaml.load(meta.read_text(encoding="utf-8-sig"), Loader=LOADER)
            imp = doc["TextureImporter"]
            path = Path(str(meta)[:-5])
            texture = Image.open(path).convert("RGBA")
            for entry in imp["spriteSheet"]["sprites"]:
                rect = entry["rect"]
                x, y, w, h = [int(rect[k]) for k in ("x", "y", "width", "height")]
                image = texture.crop((x, texture.height-y-h, x+w, texture.height-y))
                key = (doc["guid"], int(entry["internalID"]))
                item = {"key": key, "image": image, "name": entry["name"],
                        "texture": path, "meta": meta, "rect": rect, "pivot": entry["pivot"]}
                self.sprites[key] = item
                self.named[(path.name, entry["name"])] = item

    def resolve(self, reference):
        key = (reference["guid"], int(reference["fileID"]))
        item = self.sprites[key]
        self.inputs.update([item["texture"], item["meta"]])
        return item

    def named_sprite(self, filename, name):
        item = self.named[(filename, name)]
        self.inputs.update([item["texture"], item["meta"]])
        return item


def read_scene(art, scene_path=SCENE):
    documents = unity_documents(scene_path)
    objects = {d["__file_id"]: d for d in documents}
    layers = {}
    for doc in documents:
        if "Tilemap" not in doc:
            continue
        tilemap = doc["Tilemap"]
        go = objects[tilemap["m_GameObject"]["fileID"]]["GameObject"]
        cells = {}
        for cell in tilemap["m_Tiles"]:
            entry = cell["second"]
            reference = tilemap["m_TileAssetArray"][entry["m_TileIndex"]]["m_Data"]
            if not reference.get("fileID"):
                continue
            sprite = tilemap["m_TileSpriteArray"][entry["m_TileSpriteIndex"]]["m_Data"]
            # 本实验只使用标准 Tile 示例的已序列化精灵，不估算 RuleTile 的 Unity 缓存结果。
            item = art.resolve(sprite)
            matrix = tilemap["m_TileMatrixArray"][entry["m_TileMatrixIndex"]]["m_Data"]
            transform = tuple(matrix[k] for k in ("e00", "e01", "e10", "e11"))
            if transform != (1, 0, 0, 1):
                raise ValueError(f"示例中存在尚未支持的 Tile 变换：{transform}")
            cells[(cell["first"]["x"], cell["first"]["y"])] = (item, reference)
        layers[go["m_Name"]] = cells
    return layers


def paint_rule(art, name, cells, rng):
    """离线执行该原包固定朝向的邻接规则；不匹配时直接失败，避免默认错误 Tile。"""
    path = PACK / f"Tile Palettes/Rule Tiles/{name}.asset"
    art.inputs.add(path)
    data = unity_documents(path)[0]["MonoBehaviour"]
    rules = data["m_TilingRules"]
    result = {}
    for x, y in sorted(cells):
        for rule in rules:
            if rule["m_RuleTransform"] != 0:
                raise ValueError(f"本实验尚未支持旋转规则：{name}")
            encoded = rule.get("m_Neighbors") or ""
            neighbors = struct.unpack("<" + "i" * (len(encoded)//8), bytes.fromhex(encoded))
            positions = rule["m_NeighborPositions"]
            # Unity 的 y 轴向上，离线地图的 y 轴向下。
            if all((n == 1 and (x+p["x"], y-p["y"]) in cells) or
                   (n == 2 and (x+p["x"], y-p["y"]) not in cells) or n == 0
                   for n, p in zip(neighbors, positions)):
                item = art.resolve(rng.choice(rule["m_Sprites"]))
                result[(x, y)] = item
                break
        else:
            raise ValueError(f"{name} 在 {(x,y)} 没有匹配规则")
    return result


def polygon_cells(points, width, height):
    mask = Image.new("1", (width, height))
    ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=1)
    return {(int(x), int(y)) for x, y in zip(*np.nonzero(np.asarray(mask).T))}


def road_cells(road, width, height):
    cells = set()
    for a, b in zip(road["points"], road["points"][1:]):
        distance = max(abs(b[0]-a[0]), abs(b[1]-a[1]))
        last = None
        for step in range(distance+1):
            t = step/max(1, distance)
            cx, cy = round(a[0]+(b[0]-a[0])*t), round(a[1]+(b[1]-a[1])*t)
            centers = [(cx, cy)]
            if last and last[0] != cx and last[1] != cy:
                centers.append((cx, last[1]))
            for center_x, center_y in centers:
                radius = road["radius"]
                for dy in range(-radius, radius+1):
                    for dx in range(-radius, radius+1):
                        x, y = center_x+dx, center_y+dy
                        if 0 <= x < width and 0 <= y < height:
                            cells.add((x, y))
            last = (cx,cy)
    return cells


def generate(layout_path, output, forge_root):
    """从布局输入生成一次新实验；拒绝覆盖已有地图生成物。"""
    plan = json.loads(layout_path.read_text(encoding="utf-8"))
    if (output / "map-bundle.json").exists():
        raise FileExistsError(f"生成物已经存在，请使用新的输出目录：{output}")
    output.mkdir(parents=True, exist_ok=True)
    (output / "assets").mkdir(exist_ok=True)
    rng = random.Random(plan["seed"])
    width, height, tile = plan["width"], plan["height"], plan["tile_size"]
    art = SourceArt()
    source = read_scene(art)
    layers = defaultdict(dict)
    tile_sources = {}
    grass = art.named_sprite("Tiles.png", "Cliff5")
    for y in range(height):
        for x in range(width):
            layers["ground"][(x,y)] = grass
    lake = polygon_cells(plan["lake"], width, height)
    layers["water"] = paint_rule(art, "LakeGrass", lake, rng)
    roads = set().union(*(road_cells(r, width, height) for r in plan["roads"]))
    if roads & lake:
        raise ValueError("布局中的道路与湖面相交，不能伪造可行走水面")
    layers["path"] = paint_rule(art, "DirtPath", roads, rng)

    reserved = set(lake) | roads
    blocked = set(lake)
    chunk_audit = []
    layer_names = {
        "Ground":"ground", "GroundDecoration":"detail", "GroundShadow":"shadow",
        "WallsShadow":"wall_shadow", "Walls - Vertical":"walls_vertical",
        "Walls - Horizontal":"walls_horizontal", "Walls - Cliffs (1)":"cliff1",
        "Walls - Cliffs (2)":"cliff2", "Walls - Cliffs (3)":"cliff3",
        "Walls - Above Cliffs":"cliff_top"
    }
    for chunk in plan["chunks"]:
        left, bottom, right, top = chunk["source_bounds"]
        tx, ty = chunk["at"]
        bounds = {(tx+x-left,ty+top-y) for x in range(left,right+1) for y in range(bottom,top+1)}
        if any(x < 0 or y < 0 or x >= width or y >= height for x,y in bounds):
            raise ValueError(f"场景组合块超出地图：{chunk['id']}")
        if bounds & lake:
            raise ValueError(f"场景组合块与湖面重叠：{chunk['id']}")
        reserved.update(bounds)
        count = 0
        for original, target in layer_names.items():
            if chunk["kind"] == "ruin" and original in ["Ground", "GroundDecoration"]:
                continue
            for (x,y), (item, reference) in source[original].items():
                if left <= x <= right and bottom <= y <= top:
                    new = (tx+x-left, ty+top-y)
                    layers[target][new] = item
                    tile_sources[f"{target}:{new[0]},{new[1]}"] = reference
                    count += 1
                    if original.startswith("Walls -"):
                        blocked.add(new)
        chunk_audit.append({**chunk,"copied_layer_cells":count})

    # 采用示例中的地面细节切片，按植被簇分布，不引入绘制替代图。
    details = []
    for item, _ in source["GroundDecoration"].values():
        if re.fullmatch(r"Grass1[6789]|ExtraGrass_\d+", item["name"]):
            if item["image"].size == (tile,tile):
                details.append(item)
    if not details:
        raise ValueError("示例缺少可用的正式地面细节")
    for y in range(1,height-1):
        for x in range(1,width-1):
            if (x,y) in reserved:
                continue
            density = 0.05 + 0.45*max(0,math.sin(x*.43+y*.17)*math.cos(y*.47-x*.13))
            if rng.random() < density:
                layers["detail"][(x,y)] = rng.choice(details)

    objects = []
    occupied = []
    placement_audit = []
    def add_prop(name, x, y, solid, footprint):
        item = art.named_sprite("Props.png", name)
        image = item["image"]
        anchor = [image.width/2, image.height-2]
        filename = f"assets/{name}.png"
        image.save(output/filename)
        obj = {"id":f"{name}-{len(objects)}","prop":name,"image":filename,
               "x":x,"y":y,"anchor_px":anchor,"solid":solid,
               "footprint":footprint,"occupant_policy":"y_sort","layer":"props"}
        objects.append(obj)
        placement_audit.append({"id":obj["id"],"unity_sprite":list(item["key"]),
                                "source_rect":item["rect"],"source":str(item["texture"].relative_to(ROOT))})
        if name.startswith("Tree"):
            shadow_name = next(k[1] for k in art.named if k[0] == "PropsShadow.png" and k[1].startswith(name+"_Shadow"))
            shadow = art.named_sprite("PropsShadow.png",shadow_name)["image"]
            shadow_file = f"assets/{shadow_name}.png"
            shadow.save(output/shadow_file)
            objects.append({"id":obj["id"]+"-shadow","prop":shadow_name,"image":shadow_file,
                            "x":x-1,"y":y,"anchor_px":[shadow.width/2,shadow.height-2],
                            "solid":False,"footprint":{"shape":"none"},
                            "occupant_policy":"static_back","sortY":-1,"layer":"props"})
        return image.width, image.height

    # 树按林带布置并为树冠留空间；碰撞只取树干，不把整幅树冠当障碍。
    for _ in range(1400):
        x,y = rng.randrange(2,width-2),rng.randrange(4,height-1)
        dense = x >= 40 or (x <= 10 and y >= 23) or (y <= 5 and x >= 16)
        if not dense or any((x+dx,y+dy) in reserved for dx in range(-2,3) for dy in range(-3,2)):
            continue
        px,py = x*tile+4,y*tile+4
        if any(abs(px-a)<18 and abs(py-b)<17 for a,b in occupied):
            continue
        occupied.append((px,py))
        add_prop(rng.choice(["TreeNoApples","TreeNoApples","TreeApples"]),px,py,True,
                 {"shape":"ellipse","width":5,"depth":3,"offset":[0,0],"basis":"prop_px"})
        if len(occupied) >= 36:
            break
    for name,x,y in [("PillarTall1",26,25),("PillarMedium2",36,31),("PillarShort1",25,32),
                     ("PillarTall3",20,34),("PillarMedium3",18,34),("PillarShort2",22,34)]:
        add_prop(name,x*tile+4,y*tile+4,True,
                 {"shape":"ellipse","width":6,"depth":3,"basis":"prop_px"})
    for _ in range(180):
        x,y=rng.randrange(1,width-1),rng.randrange(1,height-1)
        if (x,y) in reserved:
            continue
        name=rng.choice(["FlowerPink","FlowerWhite","FlowerRed","GrassLong1","GrassLong2"])
        add_prop(name,x*tile+rng.randrange(1,7),y*tile+rng.randrange(1,7),False,{"shape":"none"})

    # 图集只重新排列原切片；每个 Tile 保留来源键，不创造新的地表像素。
    unique = {}
    ordered = ["ground","water","path","detail","shadow","walls_vertical","walls_horizontal",
               "cliff1","cliff2","cliff3","cliff_top","wall_shadow"]
    for name in ordered:
        for item in layers[name].values():
            if item["image"].size != (tile,tile):
                raise ValueError(f"Tile 尺寸与原规格不符：{item['name']}")
            unique.setdefault(item["key"],item)
    columns=16
    atlas=Image.new("RGBA",(columns*tile,math.ceil(len(unique)/columns)*tile))
    indices={key:i for i,key in enumerate(unique)}
    sprite_records=[]
    for key,item in unique.items():
        i=indices[key];atlas.alpha_composite(item["image"],((i%columns)*tile,(i//columns)*tile))
        sprite_records.append({"index":i,"name":item["name"],"unity_sprite":list(key),
                               "source":str(item["texture"].relative_to(ROOT)),"rect":item["rect"]})
    atlas.save(output/"assets/terrain-atlas.png")
    tileset={"schema":"generate2dmap.tileset.v1","image":"terrain-atlas.png","tile_size":tile,
             "columns":columns,"kind":"flat","materials":["minifantasy"],
             "tiles":[{"index":i} for i in range(len(unique))],"seamless_verified":False,
             "art_source":"existing"}
    write_json(output/"assets/terrain-tileset.json",tileset)
    bundle_layers=[]
    for name in ordered:
        grid=[[-1]*width for _ in range(height)]
        for (x,y),item in layers[name].items():
            grid[y][x]=indices[item["key"]]
        bundle_layers.append({"name":name,"kind":"tiles","tileset":"minifantasy","data":grid})
    bundle_layers.append({"name":"props","kind":"objects"})
    solids=[{"shape":"rect","x":x*tile,"y":y*tile,"w":tile,"h":tile}
            for x,y in sorted(blocked)]
    inputs=[{"path":str(p.relative_to(ROOT)),"sha256":sha(p)} for p in sorted(art.inputs)]
    bundle={"schema":"generate2dmap.map_bundle.v2","id":"forest-ruins","name":plan["name"],
            "world":{"width":width*tile,"height":height*tile,"unit":"px"},"tile_size":tile,
            "tilesets":[{"id":"minifantasy","manifest":"assets/terrain-tileset.json"}],
            "layers":bundle_layers,"objects":objects,
            "collision":{"actorRadius":2,"ySquash":0.65,"solids":solids},
            "spawns":[{"id":s["id"],"x":s["tile"][0]*tile+4,"y":s["tile"][1]*tile+4} for s in plan["spawns"]],
            "anchors":{t["id"]:{"point":[t["tile"][0]*tile+4,t["tile"][1]*tile+4]} for t in plan["targets"]},
            "interactions":[{"id":t["id"],"x":t["tile"][0]*tile+4,"y":t["tile"][1]*tile+4,"reach":3}
                            for t in plan["targets"]],
            "roads":[{"id":r["id"],"width":(r["radius"]*2+1)*tile,
                      "polyline":[[x*tile+4,y*tile+4] for x,y in r["points"]]} for r in plan["roads"]],
            "art_source":"existing","placeholder":False}
    write_json(output/"map-bundle.json",bundle)
    write_json(output/"layout.json",plan)
    write_json(output/"source-audit.json",{"inputs":inputs,"sprites":sprite_records,
               "chunks":chunk_audit,"props":placement_audit,"unity_tile_references":tile_sources,
               "reference":"../reference/user-reference.png","reference_sha256":sha(output.parent/"reference/user-reference.png") if (output.parent/"reference/user-reference.png").exists() else None,
               "limitations":["离线拼装，不是 Unity GameView 截图", "高台只校验地面绕行，不包含高度导航", "水体当前只使用静态帧", "未运行 InteliMap：它依赖 Unity 运行环境"]})
    sys.path.insert(0,str(forge_root/"scripts"))
    import map_bundle
    loaded=map_bundle.load_bundle(output/"map-bundle.json")
    rendered=Image.fromarray(map_bundle.render_map(loaded))
    rendered.save(output/"map-native.png")
    rendered.resize((rendered.width*3,rendered.height*3),Image.Resampling.NEAREST).save(output/"map-preview.png")
    write_json(output/"generation-report.json",{"status":"generated","tile_cells":width*height,
               "unique_original_sprites":len(unique),"objects":len(objects),"trees":len(occupied),
               "blocked_terrain_cells":len(blocked),"art_source":"existing","seed":plan["seed"]})
    print(json.dumps({"status":"generated","output":str(output),"objects":len(objects)},ensure_ascii=True))


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description="MiniFantasy 野外地图 CLI 实验；不启动 Unity")
    parser.add_argument("--layout",type=Path,default=Path(__file__).with_name("layout-forest-ruins.json"))
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--forge-root",type=Path,default=ROOT/"Temp/ai-map-forge")
    parser.add_argument("--check",action="store_true",help="生成后执行结构、寻路、严格浏览器和导出校验")
    parser.add_argument("--node-modules",type=Path,help="本机现有 Playwright 或 playwright-core 的 node_modules 目录")
    args=parser.parse_args()
    ensure_forge(args.forge_root.resolve())
    generate(args.layout.resolve(),args.output_dir.resolve(),args.forge_root.resolve())
    if args.check:
        run_checks(args.output_dir.resolve(),args.forge_root.resolve(),args.node_modules)
