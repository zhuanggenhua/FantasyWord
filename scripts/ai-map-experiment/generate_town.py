"""河渡贸易镇的离线作者工具：准备原素材组合，交由原版 Tiled 执行自动铺图。

布局 JSON 为规划输入，Tiled 地图为可编辑交付；浏览器包只从完成后的地图导出。
室内外共用世界坐标，建筑按原生分组编辑；不启动 Unity，不修改原包。
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
import math
import os
from pathlib import Path
import random
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

from PIL import Image

import generate_outdoor as shared

ROOT = shared.ROOT
TOWN = ROOT / "Assets/Art/KrishnaPalacio/MINIFANTASY - Towns I"
TOWN_SCENE = TOWN / "Scenes/Demo - Towns I Outside.unity"
INSIDE_SCENE = TOWN / "Scenes/Demo - Towns I Inside.unity"
TEMPLATES = {
    "house": [-7, 2, 1, 9],
    "long_house": [-21, 7, -11, 10],
    "tower": [2, 9, 6, 17],
    "canopy": [-9, 12, -1, 19],
}
BUILDING_LAYERS = {
    "GroundShadow": "地面阴影",
    "Walls - Buildings (1) and Tiled Props": "建筑一层",
    "Walls - Buildings (2)": "建筑二层",
    "Walls - Buildings (3)": "建筑三层",
    "Walls - Above Buildings": "屋顶",
    "WallsShadow": "墙面阴影",
}


def properties(values):
    return [{"name": key, "type": "bool" if isinstance(value, bool) else
             "float" if isinstance(value, float) else "int" if isinstance(value, int)
             else "string", "value": value} for key, value in values.items()]


def rectangle(x, y, width, height):
    return {(a, b) for b in range(y, y+height) for a in range(x, x+width)}


def layer(name, cells, width, height, visible=True):
    data = [0] * (width*height)
    for (x, y), value in cells.items():
        if not (0 <= x < width and 0 <= y < height):
            raise ValueError(f"图层 {name} 越界：{x},{y}")
        data[y*width+x] = value
    return {"type": "tilelayer", "name": name, "width": width, "height": height,
            "x": 0, "y": 0, "opacity": 1, "visible": visible, "data": data}


def base_map(width, height, layers, tilesets):
    index=0
    def assign(entries):
        nonlocal index
        for value in entries:
            index+=1;value['id']=index
            if value['type']=='group':assign(value['layers'])
    assign(layers)
    return {"type": "map", "version": "1.10", "tiledversion": "1.12.2",
            "orientation": "orthogonal", "renderorder": "right-down", "infinite": False,
            "width": width, "height": height, "tilewidth": 8, "tileheight": 8,
            "nextlayerid": index+1, "layers": layers, "tilesets": tilesets}


def tiled_layers(entries, x=0, y=0, building=None):
    """递归解析原生组偏移，所有导出消费者共用此坐标展开入口。"""
    for entry in entries:
        px=x+entry.get('offsetx',0);py=y+entry.get('offsety',0)
        if entry['type']=='group':
            props={v['name']:v['value'] for v in entry.get('properties',[])}
            yield from tiled_layers(entry['layers'],px,py,props.get('buildingId',building))
        else:yield entry,px,py,building


def opens_door(name, local_x, centre_px):
    """只打开实际门洞中心列，保留方门和尖拱门两侧的原始门框。"""
    return any(part in name for part in ('_SquareDoor_','_PointedDoor_')) and abs((local_x+.5)*8-centre_px)<4


def building_group(kit, source, building, number):
    """建筑自身拥有地板、结构、遮挡、家具和门洞；墙体始终阻挡，屋顶仅控制显示。"""
    left,bottom,right,top=TEMPLATES[building['template']]
    w,h=right-left+1,top-bottom+1;x0,y0=building['at']
    door=(building['door'][0]-x0)*8
    canopy=building['template']=='canopy'
    back=2 if building['template']=='tower' else 3
    first=back+1
    children=[];copied=0;removed_doors=0
    for original,name in BUILDING_LAYERS.items():
        cells={}
        for (x,y),(item,_) in source[original].items():
            if not (left<=x<=right and bottom<=y<=top):continue
            if item['name'].startswith(('Sidewalk','Fence','Dirt')):continue
            if opens_door(item['name'],x-left,door):
                removed_doors+=1;continue
            cells[(x-left,top-y)]=kit.tile(item);copied+=1
        if cells:
            target=layer(name,cells,w,h)
            target['properties']=properties({'renderRole':'cover','sourceLayer':name,'buildingId':building['id']})
            if canopy and original.startswith('Walls - Buildings'):
                posts={p:gid for p,gid in cells.items() if p[1]>=h-2}
                target=layer(name,{p:gid for p,gid in cells.items() if p not in posts},w,h)
                target['properties']=properties({'renderRole':'cover','sourceLayer':name,'buildingId':building['id']})
                fixed=layer(name+'立柱',posts,w,h)
                fixed['properties']=properties({'renderRole':'structure','sourceLayer':name,'buildingId':building['id']})
                children.append(fixed)
            children.append(target)
    floor_gid=kit.tile(kit.town.named_sprite('Tiles.png','Floor_Inside_1'))
    flooring=layer('室内地板',{p:floor_gid for p in rectangle(1,first,w-2,h-first)},w,h)
    flooring['properties']=properties({'renderRole':'floor'})
    walls={};colliders=[];objects=[];geometry=[];next_id=10000+number*100
    def obj(name,kind,x,y,width=0,height=0,props=None):
        nonlocal next_id
        result={'id':next_id,'name':name,'type':kind,'x':x,'y':y,'width':width,'height':height,
                'rotation':0,'visible':True}
        if kind.endswith('Point'):result['point']=True
        if props:result['properties']=properties(props)
        next_id+=1;return result
    def solid(name,x,y,width,height):
        colliders.append(obj(name,'Wall',x,y,width,height))
    def tile_at(x,y,name):walls[(x,y)]=kit.tile(kit.town.named_sprite('Tiles.png',name))
    if canopy:
        for px in (1,w-2):solid('棚亭立柱',px*8,(h-2)*8,5,16)
    else:
        for px in range(1,w-1):
            tile_at(px,back-1,'Walls_Inside_67' if px==1 else 'Walls_Inside_69' if px==w-2 else 'Walls_Inside_68')
            tile_at(px,back,'Walls_Inside_75' if px==1 else 'Walls_Inside_77' if px==w-2 else 'Walls_Inside_76')
        for py in range(first,h):
            tile_at(1,py,'Walls_Inside_85');tile_at(w-2,py,'Walls_Inside_86')
        for px in range(2,w-2):
            if abs((px+.5)*8-door)>3:
                tile_at(px,h-1,'WallLargeStones_4')
        solid('后墙',8,(back-1)*8,(w-2)*8,16)
        solid('左墙',8,first*8,5,(h-first)*8)
        solid('右墙',(w-2)*8+2,first*8,4,(h-first)*8)
        solid('门洞左侧前墙',13,(h-1)*8,door-4-13,8)
        solid('门洞右侧前墙',door+4,(h-1)*8,(w-2)*8+2-door-4,8)
    structures=layer('室内墙体',walls,w,h)
    structures['properties']=properties({'renderRole':'structure'})

    def furniture(name,x,y,width,depth,offset=-2,solid=True):
        item=kit.town.named_sprite('Props.png',name);image=item['image']
        value=obj(name,'Furniture',x*8-image.width/2,y*8+2,image.width,image.height,
            {'solid':solid,'footprintWidth':width,'footprintDepth':depth,'footprintOffsetY':offset,
             'sourceSpriteGuid':item['key'][0],'sourceSpriteFileId':str(item['key'][1])})
        value['gid']=kit.sprite(item);objects.append(value)
    role=building['role']
    if building['template']=='tower':
        furniture('WallWeaponDisplay_Swords',2.4,first+.2,0,0,solid=False)
        furniture('Bench_Long',1.8,h-3.2,3,4)
    elif canopy:
        furniture('WideTable_Butcher',2.3,5.5,12,5,-4)
        furniture('WideTable_Alchemy',6.3,5.5,12,5,-4)
    elif role in ('住宅','休息'):
        furniture('BedSouth',2.8,6,9,10,-7)
        furniture('BooksSingleShortShelf',6.2,5.1,6,4,-4)
        furniture('SmallTable',6,6.2,4,4,-3)
    elif role=='交易':
        furniture('BooksSingleLongShelf',2.5,4.7,13,4,-4)
        furniture('WideTable_Desk',6.2,6.1,12,5,-4)
    elif role=='工坊':
        furniture('Anvil_Horizontal',2.8,5.8,10,5,-4)
        furniture('WeaponsRack_North',6.2,4.8,12,4,-4)
        furniture('SlackTub_Horizontal',6.1,6.1,8,4,-3)
    elif role=='仓储':
        for px,py in [(2.5,5),(3.3,5),(6.2,5),(6.2,6.2)]:
            furniture('WineKeg',px,py,7,5,-4)
    furniture_layer={'type':'objectgroup','name':'室内家具','draworder':'topdown','visible':True,'opacity':1,
        'objects':objects,'properties':properties({'renderRole':'furniture'})}
    zone=[13,first*8,(w-2)*8+2-13,(h-first)*8]
    if canopy:zone=[8,first*8,(w-2)*8,(h-first)*8]
    geometry.append(obj('室内区域','InteriorZone',*zone))
    geometry.append(obj('门口外侧','ExteriorPoint',door,(h+.5)*8))
    geometry.append(obj('室内行走点','InteriorPoint',door,(h-2.2)*8))
    geometry.append(obj('门洞','DoorOpening',door-4,(h-1)*8,8,8))
    if not canopy:geometry.append(obj('后墙校验点','WallProbe',door,back*8+4))
    collision_layer={'type':'objectgroup','name':'墙体碰撞','visible':False,'opacity':1,'objects':colliders,
        'properties':properties({'renderRole':'collision'})}
    geometry_layer={'type':'objectgroup','name':'空间与入口','visible':False,'opacity':1,'objects':geometry,
        'properties':properties({'renderRole':'geometry'})}
    group={'type':'group','name':building['name'],'offsetx':x0*8,'offsety':y0*8,'visible':True,'opacity':1,
        'layers':[flooring,structures,furniture_layer,*children,collision_layer,geometry_layer],
        'properties':properties({'buildingId':building['id'],'用途':role,'floorLevel':0,
            'continuousInterior':True,'widthTiles':w,'heightTiles':h})}
    return group,{**building,'rect':[x0,y0,w,h],'source_bounds':[left,bottom,right,top],
        'copied_cells':copied,'opened_door_tiles':removed_doors,'interior_furniture':len(objects)}


class Kit:
    """统一登记使用到的原始切片，生成带 Unity 来源字段的 Tiled 图集。"""
    def __init__(self, output):
        self.output = output
        self.town = shared.SourceArt(TOWN, TOWN_SCENE)
        self.town.inputs.add(INSIDE_SCENE)
        self.plains = shared.SourceArt()
        self.tiles = {}
        self.props = {}
        self.audit = []

    def tile(self, item):
        if item["image"].size != (8, 8):
            raise ValueError(f"瓦片不是原生 8×8：{item['name']}")
        key = item["key"]
        if key not in self.tiles:
            self.tiles[key] = (len(self.tiles)+1, item)
        return self.tiles[key][0]

    def resolve_tile(self, reference):
        key = (reference["guid"], reference["fileID"])
        if key in self.town.sprites:
            return self.tile(self.town.resolve(reference))
        return self.tile(self.plains.resolve(reference))

    def sprite(self, item):
        key = item["key"]
        if key not in self.props:
            index = len(self.props)
            filename = f"prop-{index:03}.png"
            item["image"].save(self.output / "assets" / filename)
            self.props[key] = (10000+index, item, filename)
        return self.props[key][0]

    def save(self):
        columns = 32
        image = Image.new("RGBA", (columns*8, math.ceil(len(self.tiles)/columns)*8))
        tileset = ET.Element("tileset", {"version": "1.10", "tiledversion": "1.12.2",
            "name": "MiniFantasy 原素材", "tilewidth": "8", "tileheight": "8",
            "tilecount": str(len(self.tiles)), "columns": str(columns)})
        ET.SubElement(tileset, "image", {"source": "terrain.png", "width": str(image.width),
                                        "height": str(image.height)})
        for gid, item in self.tiles.values():
            index = gid-1
            image.alpha_composite(item["image"], ((index % columns)*8, (index//columns)*8))
            node = ET.SubElement(tileset, "tile", {"id": str(index)})
            props = ET.SubElement(node, "properties")
            for key, value in {"原始名称": item["name"], "unitySpriteGuid": item["key"][0],
                               "unitySpriteFileId": str(item["key"][1])}.items():
                ET.SubElement(props, "property", {"name": key, "value": value})
            self.audit.append({"gid": gid, "name": item["name"], "sprite": list(item["key"]),
                               "rect": item["rect"], "texture": str(item["texture"].relative_to(ROOT))})
        image.save(self.output/"assets/terrain.png")
        ET.ElementTree(tileset).write(self.output/"assets/terrain.tsx", encoding="utf-8", xml_declaration=True)
        collection = ET.Element("tileset", {"version": "1.10", "tiledversion": "1.12.2",
            "name": "MiniFantasy 独立物件", "tilewidth": "32", "tileheight": "32",
            "tilecount": str(len(self.props)), "columns": "0", "objectalignment": "bottomleft"})
        for gid, item, filename in self.props.values():
            node = ET.SubElement(collection, "tile", {"id": str(gid-10000)})
            ET.SubElement(node, "image", {"source": filename, "width": str(item["image"].width),
                                          "height": str(item["image"].height)})
            self.audit.append({"gid": gid, "name": item["name"], "sprite": list(item["key"]),
                               "rect": item["rect"], "texture": str(item["texture"].relative_to(ROOT))})
        ET.ElementTree(collection).write(self.output/"assets/props.tsx", encoding="utf-8", xml_declaration=True)


def build_rule_map(kit, semantics):
    """把原包固定朝向邻接规则翻译成 Tiled 原生 Automapping 输入与输出。"""
    positive, negative, paving, water = {}, {}, {}, {}
    index = 0
    for path, marker, target in [
        (TOWN/"Tile Palettes/Rule Tiles/Cobblestone.asset", semantics["road"], paving),
        (shared.PACK/"Tile Palettes/Rule Tiles/LakeGrass.asset", semantics["water"], water)
    ]:
        data = shared.unity_documents(path)[0]["MonoBehaviour"]
        for rule in data["m_TilingRules"]:
            if rule["m_RuleTransform"] != 0:
                raise ValueError("规则包含未支持的旋转")
            cx, cy = (index % 8)*5+2, (index//8)*5+2
            positive[(cx, cy)] = marker
            encoded = rule.get("m_Neighbors") or ""
            neighbors = struct.unpack("<"+"i"*(len(encoded)//8), bytes.fromhex(encoded))
            for kind, position in zip(neighbors, rule["m_NeighborPositions"]):
                point = (cx+position["x"], cy-position["y"])
                if kind == 1:
                    positive[point] = marker
                elif kind == 2:
                    negative[point] = marker
                elif kind != 0:
                    raise ValueError(f"未知规则邻居：{kind}")
            # 本轮采用第一静态帧，避免把尚未验证的动画或随机变换当作已接入。
            target[(cx, cy)] = kit.resolve_tile(rule["m_Sprites"][0])
            index += 1
    layers = [layer("input_规划输入", positive, 40, 20),
              layer("inputnot_规划输入", negative, 40, 20),
              layer("output_道路", paving, 40, 20), layer("output_水面", water, 40, 20)]
    result = base_map(40, 20, layers, [{"firstgid": 1, "source": "assets/terrain.tsx"}])
    result["properties"] = properties({"MatchOutsideMap": True})
    shared.write_json(kit.output/"town-rules.tmj", result)


def prepare(plan_path, output):
    """准备设计图层、完整房屋组合、道具与规则；最终铺图由 Tiled 执行。"""
    if output.exists():
        raise FileExistsError(f"请使用新的输出目录：{output}")
    output.mkdir(parents=True)
    (output/"assets").mkdir()
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    width, height = plan["width"], plan["height"]
    kit = Kit(output)
    rng = random.Random(plan["seed"])
    cells = defaultdict(dict)
    source = shared.read_scene(kit.town, TOWN_SCENE)
    grass = kit.tile(kit.plains.named_sprite("Tiles.png", "Cliff5"))
    for y in range(height):
        for x in range(width):
            cells["地面"][(x, y)] = grass
    road_marker = kit.tile(kit.town.named_sprite("Tiles.png", "Cobblestone_10"))
    water_marker = kit.tile(kit.plains.named_sprite("Tiles.png", "LakeGrass5b"))
    river = shared.polygon_cells(plan["river"], width, height)
    paving = set().union(*(rectangle(*r) for r in plan["paving_rects"]+plan.get('street_links',[])))
    bridge_decks, bridge_rails = set(), set()
    for bridge in plan["bridges"]:
        x, y, w, h = bridge["rect"]
        bridge_decks.update(rectangle(x, y+1, w, h-2))
        bridge_rails.update(rectangle(x, y, w, 1) | rectangle(x, y+h-1, w, 1))
    paving = (paving-river) | bridge_decks
    for point in river:
        cells["规划输入"][point] = water_marker
    # 两个独立概念层避免桥面覆盖河道的输入；水面仍会在桥下完整生成。
    water_semantics = dict(cells["规划输入"])
    for point in paving:
        cells["规划输入"][point] = road_marker
    beam = kit.tile(kit.town.named_sprite("Tiles.png", "WoodenBeams_1"))
    for point in bridge_rails:
        cells["桥梁护栏"][point] = beam
    occupied, lots, groups = set(), [], []
    for number,building in enumerate(plan["buildings"]):
        left, bottom, right, top = TEMPLATES[building["template"]]
        x0, y0 = building["at"]
        footprint = rectangle(x0, y0, right-left+1, top-bottom+1)
        if footprint & (river | occupied):
            raise ValueError(f"建筑占地冲突：{building['name']}")
        occupied.update(footprint)
        group,lot=building_group(kit,source,building,number)
        groups.append(group);lots.append(lot)
    reserved = occupied | river | paving | bridge_rails
    objects, collision_objects = [], []
    fence_cells = set()
    for fence in plan.get('fences', []):
        x,y,w,h=fence['rect']; gaps={tuple(point) for point in fence['gaps']}
        outline=rectangle(x,y,w,1)|rectangle(x,y+h-1,w,1)|rectangle(x,y,1,h)|rectangle(x+w-1,y,1,h)
        for px,py in sorted(outline-gaps):
            if py==y: index=0 if px==x else 3 if px==x+w-1 else 2
            elif py==y+h-1: index=6 if px==x else 9 if px==x+w-1 else 8
            else:index=4 if px==x else 5
            cells['院落围栏'][(px,py)]=kit.tile(kit.town.named_sprite('Tiles.png','Fence_'+str(index)))
            fence_cells.add((px,py))
            collision_objects.append({'id':6000+len(fence_cells),'name':'院落围栏','x':px*8,'y':py*8,
                'width':8,'height':8,'rotation':0,'visible':True})
    reserved.update(fence_cells)
    object_id = 1
    prop_centers = []

    def add_prop(name, x, y, catalog="town", solid=True, footprint=(6, 4), shadow=None):
        nonlocal object_id
        art = kit.town if catalog == "town" else kit.plains
        filename = "Props.png"
        item = art.named_sprite(filename, name)
        gid = kit.sprite(item)
        image = item["image"]
        px, py = x*8, y*8
        obj = {"id": object_id, "name": name, "type": "Scenery", "gid": gid,
               "x": px-image.width/2, "y": py+2, "width": image.width,
               "height": image.height, "rotation": 0, "visible": True,
               "properties": properties({"solid": solid, "groundX": px, "groundY": py,
                    "footprintWidth": footprint[0], "footprintDepth": footprint[1],
                    "sourceSpriteGuid": item["key"][0], "sourceSpriteFileId": str(item["key"][1])})}
        objects.append(obj)
        object_id += 1
        prop_centers.append((x, y))
        if shadow:
            filename = "PropsShadows.png" if catalog == "town" else "PropsShadow.png"
            shadow_item = art.named_sprite(filename, shadow)
            shadow_image = shadow_item["image"]
            objects.append({"id": object_id, "name": name+" 阴影", "type": "Shadow",
                "gid": kit.sprite(shadow_item), "x": px-shadow_image.width/2-1,
                "y": py+2, "width": shadow_image.width, "height": shadow_image.height,
                "rotation": 0, "visible": True,
                "properties": properties({"solid": False, "sortY": -1})})
            object_id += 1

    # 市场以棚亭与井为中心，摊位围绕边缘摆放，保留过桥后的转向与环行空间。
    for name,x,y in [("Well",49,29),("WideTable_Butcher",35,34),("WideTable_Alchemy",49,25),
                      ("WideTable_Desk",52,32),("WineKeg",35,31),("WineKeg",35,32),
                      ("Bench_Wide",47,35),("Bench_Wide",51,35),
                      ("Anvil_Horizontal",61,22),("WineKeg",59,22),
                      ("ShopSign_Tavern",30,20),("ShopSign_Potions",48,20),
                      ("ShopSign_Weapons",58,22),
                      ("PottedPlant_1",39,48.8),("PottedPlant_2",49.5,48.5),
                      ("Bench_Wide",61.5,38.5),("PottedPlant_1",59,38.5),
                      ("PottedPlant_2",64,38.5),("WineKeg",5,23),("WineKeg",6,23),
                      ("PottedPlant_3",73,41.5)]:
        add_prop(name,x,y,footprint=(6,3),solid=not name.startswith("ShopSign"))
    # 西岸石塔周边使用原包旧石柱与草丛，强化旧仓区与东岸市场的差异。
    for name,x,y in [("PillarMedium2",6,9),("PillarShort1",16,14),
                      ("PillarShort2",5,15),("PillarMedium3",16,20)]:
        add_prop(name,x,y,"plains",footprint=(5,3))
    trees = []
    for _ in range(5000):
        x, y = rng.randrange(2,width-2), rng.randrange(4,height-2)
        edge = x <= 4 or x >= 76 or y <= 5 or y >= 55
        river_grove = 14 <= x <= 18 and 34 <= y <= 42
        pocket = any(a<=x<a+w and b<=y<b+h for a,b,w,h in plan.get('tree_pockets',[]))
        if not (edge or river_grove or pocket):
            continue
        if any((x+dx,y+dy) in reserved for dx in range(-2,3) for dy in range(-3,2)):
            continue
        if any(abs(x-a)<2.8 and abs(y-b)<2.3 for a,b in trees):
            continue
        trees.append((x,y))
        add_prop("TreeNoApples",x+.5,y+.5,"plains",footprint=(5,3),shadow="TreeNoApples_Shadow_9")
        if len(trees) >= 62:
            break
    # 草丛聚在围墙、岸线与林带，不对铺装道路和院落均匀撒点。
    detail = [kit.tile(kit.plains.named_sprite("Tiles.png",name)) for name in ["Grass18","Grass19"]]
    for y in range(1,height-1):
        for x in range(1,width-1):
            if (x,y) in reserved:
                continue
            density = 0.08 if x > 30 and 18 < y < 53 else 0.24
            if rng.random() < density and math.sin(x*.3+y*.21)*math.cos(y*.35) > .15:
                cells["植被细节"][(x,y)] = rng.choice(detail)
    # 原版规则在各自的概念层上执行，桥下水面也保留。
    cells["水域输入"] = water_semantics
    build_rule_map(kit,{"road":road_marker,"water":water_marker})
    rules = json.loads((output/"town-rules.tmj").read_text(encoding="utf-8"))
    # 水规则与道路规则分别读取相应的概念层。
    for entry in rules["layers"][:2]:
        grid = entry["data"]
        water_grid = [value if value == water_marker else 0 for value in grid]
        entry["data"] = [value if value == road_marker else 0 for value in grid]
        rules["layers"].append({**entry,"id":len(rules["layers"])+1,
                                "name":entry["name"].replace("规划输入","水域输入"),"data":water_grid})
    shared.write_json(output/"town-rules.tmj",rules)
    for i,(x,y) in enumerate(sorted((river-bridge_decks) | bridge_rails)):
        collision_objects.append({"id":1000+i,"name":"河岸或桥栏阻挡","x":x*8,"y":y*8,
                                  "width":8,"height":8,"rotation":0,"visible":True})
    design_objects=[]
    for i,point in enumerate(plan["points"]):
        x,y=point["point"]
        design_objects.append({"id":4500+i,"name":point["name"],"type":"ExploreTarget",
            "point":True,"x":x*8,"y":y*8,"rotation":0,"visible":True,
            "properties":properties({"stableId":point["id"]})})
    order=["规划输入","水域输入","地面","水面","道路","植被细节","地面阴影","院落围栏",
           "桥梁护栏"]
    map_layers=[layer(name,cells[name],width,height,name not in ["规划输入","水域输入"]) for name in order]
    objects.sort(key=lambda obj:(dict((p['name'],p['value']) for p in obj.get('properties',[])).get('sortY',obj['y']),obj['x']))
    map_layers += [*groups,{"type":"objectgroup","name":"道具","draworder":"index","objects":objects,"visible":True,"opacity":1},
                   {"type":"objectgroup","name":"碰撞规划","draworder":"index","objects":collision_objects,"visible":False,"opacity":1},
                   {"type":"objectgroup","name":"建筑入口与探索点","objects":design_objects,"visible":False,"opacity":1}]
    draft=base_map(width,height,map_layers,[{"firstgid":1,"source":"assets/terrain.tsx"},
                                          {"firstgid":10000,"source":"assets/props.tsx"}])
    draft["nextobjectid"]=12000
    draft["properties"]=properties({"名称":plan["name"],"设计意图":plan["intent"],"art_source":"existing",
        'worldMode':'continuous','mapId':'river-trade-town','sceneTransitions':False})
    kit.save()
    shared.write_json(output/"draft-town.tmj",draft)
    shared.write_json(output/"layout.json",plan)
    shared.write_json(output/"source-audit.json",{"tiles":kit.audit,"buildings":lots,
        "source_scene":str(TOWN_SCENE.relative_to(ROOT)),"source_scene_sha256":shared.sha(TOWN_SCENE),
        "originals":[{"path":str(p.relative_to(ROOT)),"sha256":shared.sha(p)}
                     for p in sorted(kit.town.inputs | kit.plains.inputs |
                        {TOWN/'Tile Palettes/Rule Tiles/Cobblestone.asset',
                         shared.PACK/'Tile Palettes/Rule Tiles/LakeGrass.asset'})],"art_source":"existing"})
    return plan


def tiled_environment(executable):
    result=os.environ.copy()
    result['QT_QPA_PLATFORM_PLUGIN_PATH']=str(executable.parent/'plugins/platforms')
    return result


def export_preview_bundle(output,plan):
    """仅从 Tiled 保存结果导出浏览器检查数据，避免检查草稿或并行地图状态。"""
    tiled=json.loads((output/'river-trade-town.tmj').read_text(encoding='utf-8'))
    width,height=tiled['width'],tiled['height']
    atlas=Image.open(output/'assets/terrain.png')
    count=len(ET.parse(output/'assets/terrain.tsx').findall('tile'))
    shared.write_json(output/'assets/terrain-forge.json',{
        'schema':'generate2dmap.tileset.v1','image':'terrain.png','tile_size':8,
        'columns':atlas.width//8,'kind':'flat','materials':['minifantasy'],
        'tiles':[{'index':i} for i in range(count)],'seamless_verified':False,'art_source':'existing'})
    prop_first=next(v['firstgid'] for v in tiled['tilesets'] if v['source'].endswith('props.tsx'))
    prop_images={int(n.attrib['id'])+prop_first:n.find('image').attrib
                 for n in ET.parse(output/'assets/props.tsx').findall('tile')}
    layers=[];objects=[];solids=[];targets=[]
    for original,ox,oy,building in tiled_layers(tiled['layers']):
        name=original['name']
        role={p['name']:p['value'] for p in original.get('properties',[])}.get('renderRole')
        if original['type']=='tilelayer' and original.get('visible',True) and role!='cover':
            flat=original['data']
            grid=[[-1]*width for _ in range(height)]
            for i,value in enumerate(flat):
                x=i%original['width']+int(ox/8);y=i//original['width']+int(oy/8)
                if value:grid[y][x]=value-1
            layers.append({'name':(building+'-' if building else '')+name,'kind':'tiles','tileset':'minifantasy','data':grid})
        elif name=='道具' or role=='furniture':
            for obj in original['objects']:
                image=prop_images[obj['gid']];props={p['name']:p['value'] for p in obj.get('properties',[])}
                w,h=int(image['width']),int(image['height'])
                item={'id':'prop-'+str(obj['id']),'prop':obj['name'],'image':'assets/'+image['source'],
                    'x':obj['x']+ox,'y':obj['y']+oy,'anchor_px':[0,h],'solid':bool(props.get('solid',False)),
                    'footprint':{'shape':'rect','width':props.get('footprintWidth',0),
                                 'depth':props.get('footprintDepth',0),'offset':[w/2,props.get('footprintOffsetY',-2)]},
                    'layer':'props','occupant_policy':'static_back' if obj['type']=='Shadow' else 'y_sort'}
                if 'sortY' in props:item['sortY']=props['sortY']
                objects.append(item)
        elif name=='碰撞规划' or role=='collision':
            solids.extend({'shape':'rect','x':o['x']+ox,'y':o['y']+oy,'w':o['width'],'h':o['height']} for o in original['objects'])
        elif role=='geometry':
            targets.extend({'id':building+'-'+o['type'],'x':o['x']+ox,'y':o['y']+oy,'reach':2}
                for o in original['objects'] if o['type'] in ('InteriorPoint','ExteriorPoint'))
        elif name=='建筑入口与探索点':
            targets.extend({'id':'target-'+str(o['id']),'x':o['x'],'y':o['y'],'reach':3} for o in original['objects'])
    concept=next(v['data'] for v in tiled['layers'] if v['name']=='规划输入')
    road=next(v['data'] for v in tiled['layers'] if v['name']=='道路')
    water=next(v['data'] for v in tiled['layers'] if v['name']=='水面')
    water_concept=next(v['data'] for v in tiled['layers'] if v['name']=='水域输入')
    expected_road=sum(v==concept[27*width] for v in concept)
    missing_roads=[i for i,v in enumerate(concept) if v==concept[27*width] and not road[i]]
    missing_water=[i for i,v in enumerate(water_concept) if v and not water[i]]
    if missing_roads or missing_water:
        raise ValueError(f'Tiled 规则覆盖不完整：道路 {len(missing_roads)}，水面 {len(missing_water)}')
    layers.append({'name':'props','kind':'objects'})
    sx,sy=plan['spawn']['point']
    bundle={'schema':'generate2dmap.map_bundle.v2','id':'river-trade-town','name':plan['name'],
        'world':{'width':width*8,'height':height*8,'unit':'px'},'tile_size':8,
        'tilesets':[{'id':'minifantasy','manifest':'assets/terrain-forge.json'}],
        'layers':layers,'objects':objects,'collision':{'actorRadius':2,'ySquash':.65,'solids':solids},
        'spawns':[{'id':plan['spawn']['id'],'x':sx*8,'y':sy*8}],
        'interactions':targets,'art_source':'existing','placeholder':False}
    audit=json.loads((output/'source-audit.json').read_text(encoding='utf-8'))
    for entry in audit['tiles']:
        entry.setdefault('draft_gid',entry['gid'])
        entry['gid']=entry['draft_gid']-10000+prop_first if entry['draft_gid']>=10000 else entry['draft_gid']
    audit['gid_source']='river-trade-town.tmj 中 Tiled 保存后的全局编号；draft_gid 保留输入编号'
    shared.write_json(output/'source-audit.json',audit)
    shared.write_json(output/'map-bundle.json',bundle)
    shared.write_json(output/'rule-coverage.json',{'status':'pass','roads':expected_road,
        'water':sum(bool(v) for v in water_concept),'missing_road_cells':missing_roads,
        'missing_water_cells':missing_water,'source':'river-trade-town.tmj'})


def main():
    parser=argparse.ArgumentParser(description='用原版 Tiled CLI 生成河渡贸易镇，不启动 Unity')
    parser.add_argument('--layout',type=Path,default=Path(__file__).with_name('layout-river-trade-town.json'))
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--tiled',type=Path,default=ROOT/'Temp/tiled-1.12.2/app/tiled.exe')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--node-modules',type=Path)
    args=parser.parse_args();output=args.output_dir.resolve();executable=args.tiled.resolve()
    if not executable.is_relative_to((ROOT/'Temp').resolve()):
        raise ValueError('生成扩展只允许写入本工程 Temp 内的独立便携 Tiled，不能使用或改写用户安装的 Tiled 配置')
    if not executable.is_file():raise FileNotFoundError(f'缺少原版 Tiled 可执行文件：{executable}')
    plan=prepare(args.layout.resolve(),output)
    shared.write_json(output/'generation.tiled-project',{'folders':['.'],'extensionsPath':'project-extensions',
        'automappingRulesFile':'town-rules.tmj'})
    # 扩展只放在本任务 Temp 便携副本；不改变用户安装或第三方插件。
    ini=executable.parent/'tiled.ini'
    ini.write_text('[General]\n',encoding='utf-8')
    extension=executable.parent/'extensions/river-town.js'
    extension.parent.mkdir(exist_ok=True)
    shutil.copyfile(Path(__file__).with_name('tiled_town.js'),extension)
    command=[str(executable),'--new-instance','--disable-opengl','--project',
             str(output/'generation.tiled-project'),str(output/'draft-town.tmj')]
    startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    result=subprocess.run(command,env=tiled_environment(executable),startupinfo=startup,
                          capture_output=True,timeout=90,check=True)
    (output/'tiled-cli.log').write_bytes(result.stdout+result.stderr)
    if (output/'tiled-error.txt').exists():raise RuntimeError((output/'tiled-error.txt').read_text(encoding='utf-8'))
    if not (output/'tiled-report.json').is_file():raise RuntimeError('Tiled 未写入执行报告')
    native=Image.open(output/'tiled-native.png')
    native.resize((native.width*2,native.height*2),Image.Resampling.NEAREST).save(output/'town-overview.png')
    inside=Image.open(output/'tiled-interiors.png')
    inside.resize((inside.width*2,inside.height*2),Image.Resampling.NEAREST).save(output/'town-interiors.png')
    export_preview_bundle(output,plan)
    if args.check:
        shared.ensure_forge(ROOT/'Temp/ai-map-forge')
        env=os.environ.copy()
        if args.node_modules:env['NODE_PATH']=str(args.node_modules)
        commands=[['map_bundle.py','validate','--bundle',str(output/'map-bundle.json'),'--report',str(output/'bundle-report.json')],
                  ['map_nav.py','check','--bundle',str(output/'map-bundle.json'),'--output-dir',str(output/'nav'),'--publish-on-fail'],
                  ]
        for tool,*arguments in commands:
            subprocess.run([sys.executable,'-X','utf8',str(ROOT/'Temp/ai-map-forge/scripts'/tool),*arguments],
                           cwd=ROOT,env=env,check=True)
    import town_preview
    town_preview.build(output,verify=args.check,node_modules=args.node_modules)
    print(json.dumps({'status':'generated','output':str(output),'tiled':'1.12.2','unity_verified':False}))


if __name__=='__main__':
    main()
