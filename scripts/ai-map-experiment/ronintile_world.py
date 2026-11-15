"""原素材小镇作者工具：准备原引擎工作流，消费原生导出制作连续室内预览。"""
from __future__ import annotations

import argparse
import base64
from collections import defaultdict
import io
import json
import math
from pathlib import Path
import random
import shutil
import struct
import sys
import numpy as np
import xml.etree.ElementTree as ET

import generate_outdoor as art_source
import generate_town as town
from PIL import Image


def save(path, value):
    art_source.write_json(path, value)


def props(value):
    return {p['name']: p['value'] for p in value.get('properties', [])}


def rect(x, y, w, h):
    return {(a, b) for b in range(y, y+h) for a in range(x, x+w)}


def stroke(points, radius):
    result = set()
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        length = max(abs(ax-bx), abs(ay-by))
        for i in range(length+1):
            x = round(ax+(bx-ax)*i/max(1, length))
            y = round(ay+(by-ay)*i/max(1, length))
            result |= rect(x-radius, y-radius, radius*2+1, radius*2+1)
    return result


def prepare(output):
    if output.exists():
        raise FileExistsError(output)
    output.mkdir(parents=True)
    (output/'assets').mkdir()
    kit = town.Kit(output)
    source = art_source.read_scene(kit.town, town.TOWN_SCENE)
    width, height = 96, 72
    world = rect(0, 0, width, height)
    building_specs = [
        ('old_watch', '西侧旧哨塔', 'tower', (6, 4), '守望'),
        ('home_a', '北巷住宅', 'house', (12, 15), '住宅'),
        ('inn', '驿站旅馆', 'house', (24, 17), '休息'),
        ('guild', '商队会所', 'house', (41, 15), '交易'),
        ('warehouse', '西侧货栈', 'house', (9, 38), '仓储'),
        ('market_hall', '集市棚亭', 'canopy', (30, 29), '交易'),
        ('smith', '铁匠工坊', 'house', (40, 43), '工坊'),
        ('home_b', '南侧庭院', 'house', (22, 50), '住宅'),
        ('home_c', '南岸住宅', 'house', (40, 56), '住宅'),
        ('east_watch', '东岸路塔', 'tower', (77, 12), '守望'),
    ]
    groups, buildings, occupied = [], [], set()
    for index, (bid, name, template, at, role) in enumerate(building_specs):
        w = 5 if template == 'tower' else 9
        h = 9 if template == 'tower' else 8
        spec = {'id': bid, 'name': name, 'template': template, 'at': list(at),
                'door': [at[0]+w/2, at[1]+h+.5], 'role': role}
        group, lot = town.building_group(kit, source, spec, index)
        groups.append(group)
        occupied |= rect(*at, w, h)
        buildings.append({'id': bid, 'name': name, 'x': at[0]*8, 'y': at[1]*8,
                          'width': w*8, 'height': h*8, 'geometry': {}, 'walls': []})
    grass = kit.tile(kit.plains.named_sprite('Tiles.png', 'Cliff5'))
    road = kit.tile(kit.town.named_sprite('Tiles.png', 'Cobblestone_7'))
    river = art_source.polygon_cells([[61, 0], [66, 0], [66, 20], [69, 30], [67, 45],
                                    [70, 60], [69, 72], [63, 72], [63, 60], [60, 45],
                                    [61, 30], [58, 20]], width, height)
    bridges = [(57, 29, 14, 7), (60, 55, 13, 6)]
    decks = set().union(*(rect(x, y+1, w, h-2) for x, y, w, h in bridges))
    paths = [
        ([(0, 30), (19, 30), (19, 28), (36, 28), (36, 32), (70, 32), (70, 36), (95, 36)], 2),
        ([(8, 14), (8, 24), (17, 24), (19, 28)], 1),
        ([(28, 26), (28, 28)], 1), ([(45, 24), (45, 28)], 1),
        ([(19, 30), (19, 48), (14, 48), (14, 46)], 1),
        ([(19, 48), (19, 60), (35, 60), (35, 65), (51, 65), (51, 32)], 1),
        ([(27, 59), (27, 60)], 1), ([(44, 64), (44, 65)], 1),
        ([(44, 52), (51, 52)], 1),
        ([(51, 58), (82, 58), (82, 36)], 1),
        ([(80, 22), (80, 36)], 1),
    ]
    roads = set().union(*(stroke(p, r) for p, r in paths)) | rect(25, 27, 23, 15)
    roads = (roads & world) - occupied - river - decks
    if river & occupied:
        raise ValueError('河道与建筑占地冲突')

    def read_rules(art, path):
        data = art_source.unity_documents(path)[0]['MonoBehaviour']
        result = []
        for rule in data['m_TilingRules']:
            neighbors = struct.unpack('<'+'i'*(len(rule['m_Neighbors'])//8), bytes.fromhex(rule['m_Neighbors']))
            result.append({'neighbors': [{'x': p['x'], 'y': -p['y'], 'value': n}
                                         for n, p in zip(neighbors, rule['m_NeighborPositions'])],
                           'gid': kit.tile(art.resolve(rule['m_Sprites'][0]))})
        # 原包的DefaultSprite可为红色编辑标记；材质主体必须取八邻居同类的正式规则。
        body = next(r['gid'] for r in result if r['neighbors'] and all(n['value'] in (0, 1) for n in r['neighbors']))
        return body, result

    water, water_rules = read_rules(kit.plains, art_source.PACK/'Tile Palettes/Rule Tiles/LakeGrass.asset')
    _, road_rules = read_rules(kit.town, town.TOWN/'Tile Palettes/Rule Tiles/Cobblestone.asset')
    details = [kit.tile(kit.plains.named_sprite('Tiles.png', n)) for n in ['Grass18', 'Grass19']]
    wood = kit.tile(kit.town.named_sprite('Tiles.png', 'Floor_Inside_0'))
    beam = kit.tile(kit.town.named_sprite('Tiles.png', 'WoodenBeams_1'))

    # 临时层描述只负责准备作者命令，最终预览只读取原引擎保存的project.json与原生JSON导出。
    layers = []
    metadata = {'mapId': 'stoneford-waystation', 'name': '石渡驿站', 'width': width*8,
                'height': height*8, 'spawn': [20, 244], 'buildings': buildings, 'layers': [],
                'solids': [], 'props': [], 'artSource': 'existing'}

    def add_layer(name, cells, role='background', **extra):
        index = len(layers)
        layers.append({'name': name, 'cells': cells, 'role': role, **extra})
        metadata['layers'].append({'name': name, 'role': role, **extra})
        return index

    add_layer('地面', {p: grass for p in world})
    add_layer('河道', {p: water for p in river}, material='water')
    add_layer('商路与广场', {p: road for p in roads}, material='road')
    add_layer('桥面', {p: wood for p in decks & world})
    rail_cells = set().union(*(rect(x, y, w, 1) | rect(x, y+h-1, w, 1) for x, y, w, h in bridges))
    add_layer('桥栏', {p: beam for p in rail_cells & world})
    for x, y, w, h in bridges:
        metadata['solids'].extend([{'shape': 'rect', 'x': x*8, 'y': y*8+2, 'w': w*8, 'h': 3},
                                   {'shape': 'rect', 'x': x*8, 'y': (y+h-1)*8+2, 'w': w*8, 'h': 3}])
    metadata['solids'].extend({'shape': 'rect', 'x': x*8, 'y': y*8, 'w': 8, 'h': 8} for x, y in river-decks)
    reserved = occupied | river | roads | decks | rail_cells
    rng = random.Random(20261030)
    vegetation = {p: rng.choice(details) for p in sorted(world-reserved)
                  if rng.random() < .13 and math.sin(p[0]*.31+p[1]*.17) > .2}
    add_layer('低矮植被', vegetation)
    covers, objects = [], []
    prop_index = 0

    def add_prop(item, x, y, width=5, depth=3, solid=True, building=None, name=None, offset=-2):
        nonlocal prop_index
        if item['image'].getbbox() is None:
            return
        gid = kit.sprite(item)
        left, top = round(x/8)*8, round(y/8)*8
        prop_index += 1
        pid = f'object-{prop_index}'
        obj = {'id': pid, 'name': name or item['name'], 'gid': gid, 'x': left, 'y': top,
               'width': item['image'].width, 'height': item['image'].height,
               'sortY': top+item['image'].height, 'solid': solid,
               'footprint': {'shape': 'rect', 'width': width, 'depth': depth,
                             'offset': [item['image'].width/2, offset]}, 'buildingId': building}
        metadata['props'].append(obj)
        objects.append((obj['sortY'], pid, obj))

    for group, building in zip(groups, buildings):
        ox, oy = group['offsetx'], group['offsety']
        for child in group['layers']:
            role = props(child).get('renderRole')
            if child['type'] == 'tilelayer':
                cells = {(i % child['width']+ox//8, i//child['width']+oy//8): gid
                         for i, gid in enumerate(child['data']) if gid}
                label = group['name']+' / '+child['name']
                if role == 'cover':
                    covers.append((building['y']+building['height'], label, cells, building['id']))
                else:
                    add_layer(label, cells, buildingId=building['id'])
            elif role == 'collision':
                building['walls'] = [{'x': o['x']+ox, 'y': o['y']+oy, 'width': o['width'], 'height': o['height']}
                                     for o in child['objects']]
                metadata['solids'].extend({'shape': 'rect', 'x': o['x'], 'y': o['y'], 'w': o['width'], 'h': o['height']}
                                          for o in building['walls'])
            elif role == 'geometry':
                building['geometry'] = {o['type']: {'x': o['x']+ox, 'y': o['y']+oy,
                                                   'width': o['width'], 'height': o['height']}
                                        for o in child['objects']}
            elif role == 'furniture':
                for obj in child['objects']:
                    item = next(v[1] for v in kit.props.values() if v[0] == obj['gid'])
                    p = props(obj)
                    add_prop(item, obj['x']+ox, obj['y']+oy-item['image'].height,
                             p['footprintWidth'], p['footprintDepth'], p['solid'], building['id'],
                             offset=p['footprintOffsetY'])
    for name, x, y in [('Well', 43, 33), ('WineKeg', 11, 47), ('WineKeg', 12, 47),
                       ('WideTable_Alchemy', 25, 38), ('Bench_Wide', 43, 40),
                       ('Anvil_Horizontal', 49, 49), ('PottedPlant_1', 22, 57),
                       ('PottedPlant_2', 49, 62), ('ShopSign_Tavern', 20, 27)]:
        item = kit.town.named_sprite('Props.png', name)
        add_prop(item, x*8, y*8-item['image'].height+2, 6, 3, not name.startswith('ShopSign'))
    tree = kit.plains.named_sprite('Props.png', 'TreeNoApples')
    tree_places = []
    for _ in range(5000):
        x, y = rng.randrange(1, width-4), rng.randrange(1, height-5)
        in_pocket = x < 5 or x > 86 or y < 4 or y > 66 or (70 < x < 75 and 5 < y < 27) or (2 < x < 22 and 50 < y < 65)
        cells = rect(x, y, math.ceil(tree['image'].width/8)+1, math.ceil(tree['image'].height/8)+1)
        if not in_pocket or cells & reserved or any(abs(x-a) < 5 and abs(y-b) < 5 for a, b in tree_places):
            continue
        tree_places.append((x, y))
        add_prop(tree, x*8, y*8)
        if len(tree_places) >= 55:
            break
    drawables = [(v[0], 'cover', v) for v in covers] + [(v[0], 'object', v) for v in objects]
    for _, kind, value in sorted(drawables, key=lambda v: (v[0], v[1])):
        if kind == 'cover':
            _, label, cells, building = value
            add_layer(label, cells, 'cover', buildingId=building)
        else:
            _, pid, obj = value
            add_layer(pid+' / '+obj['name'], {}, 'object', objectId=pid)
    kit.save()
    source_items = {gid: item for gid, item in kit.tiles.values()}
    prop_items = {v[0]: v[1] for v in kit.props.values()}

    def palette(gid):
        return [200+(gid-1) % 32, (gid-1)//32]

    steps = [{'op': 'import', 'image': 'assets/terrain.png', 'at': [200, 0]}]
    native_props = {}
    for index, (gid, item, filename) in enumerate(kit.props.values()):
        at = [240+(index % 10)*8, (index//10)*8]
        w, h = math.ceil(item['image'].width/8), math.ceil(item['image'].height/8)
        nonempty = next((x, y) for y in range(h) for x in range(w)
                        if any(any(pixel) for pixel in item['image'].crop((x*8, y*8, x*8+8, y*8+8)).getdata()))
        native_props[gid] = {'at': at, 'w': w, 'h': h, 'anchor': [at[0]+nonempty[0], at[1]+nonempty[1]],
                             'delta': nonempty}
        steps += [{'op': 'import', 'image': 'assets/'+filename, 'at': at},
                  {'op': 'prop', 'rect': [*at, w, h]}]
    for material, gid, rules, working in [('water', water, water_rules, [32, 0]), ('road', road, road_rules, [0, 0])]:
        steps += [{'op': 'call', 'function': 'setTilesSet',
                   'args': [[{'x': working[0], 'y': working[1],
                              'tile': {'$new': 'TileBase', 'args': [{'$source': palette(gid)}]}}]]},
                  {'op': 'call', 'function': 'getTileSet', 'args': working, 'as': material},
                  {'op': 'build-borders', 'kind': 'blob', 'cells': [working]},
                  {'op': 'relation', 'kind': 'blob', 'tile': material, 'other': None,
                   'slots': [{'tile': palette(gid), 'r': 0, 'c': False, 'cutoff': 0} for _ in range(12)]},
                  {'op': 'bind-borders', 'tile': material,
                   'rules': [{**r, 'source': palette(r['gid'])} for r in rules]}]
    object_by_id = {o['id']: o for o in metadata['props']}
    for z, layer in enumerate(layers):
        steps.append({'op': 'layer', **({'index': 0} if z == 0 else {}), 'name': layer['name']})
        if layer['role'] == 'object':
            obj = object_by_id[layer['objectId']]
            native = native_props[obj['gid']]
            steps.append({'op': 'paint', 'tile': native['anchor'], 'layer': z,
                          'cells': [[obj['x']//8+native['delta'][0], obj['y']//8+native['delta'][1]]]})
        elif layer.get('material'):
            steps.append({'op': 'paint', 'tile': layer['material'], 'layer': z, 'cells': sorted(layer['cells'])})
        else:
            by_gid = defaultdict(list)
            for point, gid in layer['cells'].items():
                if source_items[gid]['image'].getbbox() is not None:
                    by_gid[gid].append(list(point))
            for gid, cells in by_gid.items():
                steps.append({'op': 'draw', 'tile': palette(gid), 'layer': z, 'cells': sorted(cells)})
    for fmt in ['JSON', 'Image', 'Unity']:
        steps.append({'op': 'export', 'domain': 'map', 'format': fmt,
                      'rect': [0, 0, width, height], 'name': 'stoneford-'+fmt.lower()})
    steps += [{'op': 'save', 'name': 'stoneford'}, {'op': 'reload', 'name': 'stoneford'},
              {'op': 'render', 'rect': [0, 0, width, height], 'name': 'native-overview'}]
    save(output/'world-recipe.json', {'tileSize': 8, 'metadata': metadata, 'steps': steps})
    audit = []
    for gid, item in {**source_items, **prop_items}.items():
        audit.append({'gid': gid, 'name': item['name'], 'guid': item['key'][0],
                      'fileId': item['key'][1], 'source': str(item['texture']),
                      'sourceSha256': art_source.sha(item['texture']), 'meta': str(item['meta']),
                      'metaSha256': art_source.sha(item['meta']), 'rect': item['rect']})
    save(output/'source-audit.json', {'artSource': 'existing', 'tiles': audit,
                                   'rules': [str(art_source.PACK/'Tile Palettes/Rule Tiles/LakeGrass.asset'),
                                             str(town.TOWN/'Tile Palettes/Rule Tiles/Cobblestone.asset')]})
    save(output/'design.json', {'name': metadata['name'], 'sizeTiles': [width, height],
                              'buildings': building_specs, 'roads': len(roads), 'river': len(river),
                              'trees': len(tree_places), 'source': '原素材和原示例建筑组合，无AI整图'})
    print(json.dumps({'status': 'prepared', 'recipe': str(output/'world-recipe.json'),
                      'steps': len(steps), 'layers': len(layers), 'originalSprites': len(audit)}, ensure_ascii=False))


def export_world(native, assets_source, output, verify, node_modules):
    """只消费已保存原工程和其实际导出；位置、图层及素材不从作者草稿重新生成。"""
    import town_preview
    project_path = native/'project.json'
    project = json.loads(project_path.read_text(encoding='utf-8'))
    metadata = project['extra']['workflow']
    document = json.loads((native/'exports/stoneford-json/stoneford-json.txt').read_text(encoding='utf-8'))
    atlas_path = native/'exports/stoneford-json/stoneford-json.png'
    atlas = Image.open(atlas_path).convert('RGBA')
    width, height, size = document['map_width'], document['map_height'], document['tile_size']
    if size != 8 or [width*8, height*8] != [metadata['width'], metadata['height']]:
        raise ValueError('原生导出尺寸与已保存工程不一致')
    if output.exists():
        raise FileExistsError(output)
    output.mkdir(parents=True)
    (output/'assets').mkdir()
    shutil.copyfile(project_path, output/'project.json')
    shutil.copyfile(atlas_path, output/'assets/atlas.png')
    source_audit = json.loads((assets_source/'source-audit.json').read_text(encoding='utf-8'))
    for item in source_audit['tiles']:
        if art_source.sha(Path(item['source'])) != item['sourceSha256'] or art_source.sha(Path(item['meta'])) != item['metaSha256']:
            raise ValueError('原素材或Sprite元数据已变化：'+item['name'])
    shutil.copyfile(assets_source/'source-audit.json', output/'source-audit.json')

    def decoded(url):
        return Image.open(io.BytesIO(base64.b64decode(url.split(',', 1)[1]))).convert('RGBA')

    source_images = [decoded(s['url']) for s in project['sources']]
    original_crops = []
    for image_path in (assets_source/'assets').glob('*.png'):
        with Image.open(image_path) as image:
            image = image.convert('RGBA')
            for y in range(0, image.height, 8):
                for x in range(0, image.width, 8):
                    original_crops.append(np.array(image.crop((x, y, x+8, y+8)), dtype=np.int16))

    def visible_pixels(array):
        copy = array.copy()
        copy[copy[:, :, 3] == 0, :3] = 0
        return copy

    crops = np.stack([visible_pixels(v) for v in original_crops])
    source_errors = []
    for source_id, image in enumerate(source_images):
        pixels = visible_pixels(np.array(image, dtype=np.int16))
        differences = np.abs(crops-pixels).max(axis=(1, 2, 3))
        best = int(differences.min())
        if best > 1:
            source_errors.append({'sourceId': source_id, 'minimumPixelDifference': best})
    if source_errors:
        save(output/'source-pixel-errors.json', source_errors)
        raise ValueError('原工程有无法对应输入素材的源图，详见source-pixel-errors.json')
    source_tiles = {v['tileID'] for v in project['sandbox']}
    if any(project['tiles'][i]['type'] != 'base' for i in source_tiles):
        raise ValueError('最终地图仍引用未替换的自动生成边界，未满足全部使用原素材的要求')
    # 原版按数组键遍历图层时会把z保存成数字字符串；坐标语义仍是整数网格。
    def integer_axis(value):
        number = int(value)
        if float(value) != number:
            raise ValueError('原工程包含非整数网格坐标：'+str(value))
        return number
    native_cells = {(integer_axis(v['pos']['z']), integer_axis(v['pos']['x']), integer_axis(v['pos']['y'])):
                    v['tileID'] for v in project['sandbox']}
    layer_specs = {v['name']: v for v in metadata['layers']}
    if [l['name'] for l in document['layers']] != [l['name'] for l in project['sandbox_layers']]:
        raise ValueError('原生导出图层顺序与原工程不一致')
    tile_cache, atlas_ids = {}, {}
    for z, layer in enumerate(document['layers']):
        for pos in layer['positions']:
            key = (z, pos['x'], pos['y'])
            if key not in native_cells:
                raise ValueError('导出出现原工程不存在的坐标：'+str(key))
            tid = native_cells[key]
            previous = atlas_ids.setdefault(tid, pos['id'])
            if previous != pos['id']:
                raise ValueError('同一原图块被导出为不同图集编号')
            if pos['id'] not in tile_cache:
                x, y = (pos['id'] % 8)*8, (pos['id']//8)*8
                tile_cache[pos['id']] = atlas.crop((x, y, x+8, y+8))
            expected = source_images[project['tiles'][tid]['sourceID']]
            delta = np.abs(visible_pixels(np.array(expected, dtype=np.int16))-
                           visible_pixels(np.array(tile_cache[pos['id']], dtype=np.int16))).max()
            if delta > 1:
                raise ValueError('原生图集像素与原工程图块不一致：'+str(tid))
    count = sum(len(l['positions']) for l in document['layers'])
    if count != len(native_cells):
        raise ValueError('原生导出遗漏图块位置')

    def raster(layer):
        image = Image.new('RGBA', (width*8, height*8))
        for p in layer['positions']:
            image.alpha_composite(tile_cache[p['id']], (p['x']*8, p['y']*8))
        return image

    all_layers = []
    background = Image.new('RGBA', (width*8, height*8))
    overview = background.copy()
    covers = {b['id']: Image.new('RGBA', (b['width'], b['height'])) for b in metadata['buildings']}
    building_by_id = {b['id']: b for b in metadata['buildings']}
    objects_by_id = {o['id']: o.copy() for o in metadata['props']}
    image_cache = {}

    def embed(image):
        stream = io.BytesIO()
        image.save(stream, format='PNG')
        encoded = base64.b64encode(stream.getvalue()).decode()
        if encoded not in image_cache:
            image_cache[encoded] = len(image_cache)
        return image_cache[encoded]

    scene_objects, bundle_objects, bundle_layers, tiled_layers = [], [], [], []
    for z, layer in enumerate(document['layers']):
        spec = layer_specs[layer['name']]
        graphic = raster(layer)
        all_layers.append(graphic)
        overview.alpha_composite(graphic)
        flat = [0]*(width*height)
        grid = [[-1]*width for _ in range(height)]
        for p in layer['positions']:
            flat[p['y']*width+p['x']] = p['id']+1
            grid[p['y']][p['x']] = p['id']
        tiled_layers.append({**town.layer(layer['name'], {}, width, height), 'data': flat,
                             'properties': town.properties({'renderRole': spec['role'],
                                                             'buildingId': spec.get('buildingId', '')})})
        if spec['role'] == 'background':
            background.alpha_composite(graphic)
            bundle_layers.append({'name': layer['name'], 'kind': 'tiles', 'tileset': 'native-materials', 'data': grid})
        elif spec['role'] == 'cover':
            building = building_by_id[spec['buildingId']]
            covers[building['id']].alpha_composite(graphic.crop((building['x'], building['y'],
                                                               building['x']+building['width'], building['y']+building['height'])))
        elif spec['role'] == 'object':
            obj = objects_by_id[spec['objectId']]
            image = graphic.crop((obj['x'], obj['y'], obj['x']+obj['width'], obj['y']+obj['height']))
            filename = obj['id']+'.png'
            image.save(output/'assets'/filename)
            scene_objects.append({'id': obj['id'], 'name': obj['name'], 'image': embed(image),
                                  'x': obj['x'], 'y': obj['y'], 'sortY': obj['sortY'], 'buildingId': obj['buildingId']})
            bundle_objects.append({'id': obj['id'], 'prop': obj['name'], 'image': 'assets/'+filename,
                                   'x': obj['x'], 'y': obj['y']+obj['height'], 'anchor_px': [0, obj['height']],
                                   'solid': obj['solid'], 'footprint': obj['footprint'],
                                   'layer': 'props', 'occupant_policy': 'y_sort'})
    native_overview = Image.open(native/'native-overview.png').convert('RGBA')
    if native_overview.size != overview.size:
        raise ValueError('原版导出和本地消费视口不一致')
    overview_difference = int(np.abs(np.array(native_overview, dtype=np.int16)-np.array(overview, dtype=np.int16)).max())
    if overview_difference > 1:
        raise ValueError('独立重建画面与原版画面不一致，最大通道差：'+str(overview_difference))
    native_overview.save(output/'overview-native.png')
    native_overview.resize((width*16, height*16), Image.Resampling.NEAREST).save(output/'overview.png')
    interior = background.copy()
    for obj in scene_objects:
        art = decoded('data:image/png;base64,'+next(k for k, v in image_cache.items() if v == obj['image']))
        interior.alpha_composite(art, (obj['x'], obj['y']))
    interior.resize((width*16, height*16), Image.Resampling.NEAREST).save(output/'interiors-author-view.png')
    save(output/'assets/terrain-forge.json', {'schema': 'generate2dmap.tileset.v1', 'image': 'atlas.png',
         'tile_size': 8, 'columns': 8, 'kind': 'flat', 'materials': ['minifantasy'],
         'tiles': [{'index': i} for i in range(max(tile_cache)+1)],
         'seamless_verified': False, 'art_source': 'existing'})
    bundle_layers.append({'name': 'props', 'kind': 'objects'})
    bundle = {'schema': 'generate2dmap.map_bundle.v2', 'id': metadata['mapId'], 'name': metadata['name'],
              'world': {'width': width*8, 'height': height*8, 'unit': 'px'}, 'tile_size': 8,
              'tilesets': [{'id': 'native-materials', 'manifest': 'assets/terrain-forge.json'}],
              'layers': bundle_layers, 'objects': bundle_objects,
              'collision': {'actorRadius': 2, 'ySquash': .65, 'solids': metadata['solids']},
              'spawns': [{'id': 'road-entry', 'x': metadata['spawn'][0], 'y': metadata['spawn'][1]}],
              'interactions': [{'id': b['id']+'-'+kind, 'x': b['geometry'][kind]['x'],
                                'y': b['geometry'][kind]['y'], 'reach': 2}
                               for b in metadata['buildings'] for kind in ['ExteriorPoint', 'InteriorPoint']],
              'art_source': 'existing', 'placeholder': False}
    save(output/'map-bundle.json', bundle)
    sys.path.insert(0, str(town.ROOT/'Temp/ai-map-forge/scripts'))
    import forge_nav
    runtime_inputs = forge_nav.runtime_inputs(forge_nav.read_blocking_set(output/'map-bundle.json'))
    buildings = []
    for b in metadata['buildings']:
        probes = [{'x': o['x']+o['footprint']['offset'][0],
                   'y': o['y']+o['height']+o['footprint']['offset'][1]}
                  for o in metadata['props'] if o['buildingId'] == b['id'] and o['solid']]
        buildings.append({**b, 'cover': embed(covers[b['id']]), 'furnitureProbes': probes})
    actor_art = art_source.SourceArt(town.ROOT/'Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon', town.TOWN_SCENE)
    actor = actor_art.named_sprite('HumanBaseIdle.png', 'HumanBaseIdle_0')
    scene = {'mapId': metadata['mapId'], 'source': 'project.json', 'sourceSha256': art_source.sha(output/'project.json'),
             'width': width*8, 'height': height*8, 'background': embed(background),
             'actor': embed(actor['image']), 'actorAnchor': [15.5, 19], 'buildings': buildings,
             'objects': scene_objects, 'bundle': bundle, 'runtimeInputs': runtime_inputs,
             'actorSource': {'path': str(actor['texture'].relative_to(town.ROOT)),
                             'sha256': art_source.sha(actor['texture']), 'sprite': actor['name']}}
    town_preview.write_preview(output, scene, image_cache, verify, node_modules, metadata['name'])
    native_tmx = ET.Element('map', version='1.10', orientation='orthogonal', renderorder='right-down',
                            width=str(width), height=str(height), tilewidth='8', tileheight='8', infinite='0')
    tileset = ET.SubElement(native_tmx, 'tileset', firstgid='1', name='原版导出素材图集',
                           tilewidth='8', tileheight='8', columns='8', tilecount=str(max(tile_cache)+1))
    ET.SubElement(tileset, 'image', source='assets/atlas.png', width=str(atlas.width), height=str(atlas.height))
    for index, layer in enumerate(tiled_layers):
        node = ET.SubElement(native_tmx, 'layer', id=str(index+1), name=layer['name'], width=str(width), height=str(height))
        ET.SubElement(node, 'data', encoding='csv').text = '\n'+','.join(map(str, layer['data']))+'\n'
    object_id = 1
    collision_node = ET.SubElement(native_tmx, 'objectgroup', id=str(len(tiled_layers)+1), name='碰撞', visible='0')
    collision_objects = []
    for solid in metadata['solids']:
        ET.SubElement(collision_node, 'object', id=str(object_id), x=str(solid['x']), y=str(solid['y']),
                      width=str(solid['w']), height=str(solid['h']))
        collision_objects.append({'id': object_id, 'x': solid['x'], 'y': solid['y'], 'width': solid['w'], 'height': solid['h']})
        object_id += 1
    geometry_node = ET.SubElement(native_tmx, 'objectgroup', id=str(len(tiled_layers)+2), name='建筑空间与门洞', visible='0')
    geometry_objects = []
    for building in metadata['buildings']:
        for kind, value in building['geometry'].items():
            ET.SubElement(geometry_node, 'object', id=str(object_id), name=building['id']+'-'+kind,
                          type=kind, x=str(value['x']), y=str(value['y']), width=str(value['width']), height=str(value['height']))
            geometry_objects.append({'id': object_id, 'name': building['id']+'-'+kind, 'type': kind,
                                     'x': value['x'], 'y': value['y'], 'width': value['width'], 'height': value['height']})
            object_id += 1
    native_tmx.set('nextlayerid', str(len(tiled_layers)+3))
    native_tmx.set('nextobjectid', str(object_id))
    ET.indent(native_tmx, space='  ')
    ET.ElementTree(native_tmx).write(output/'stoneford.tmx', encoding='utf-8', xml_declaration=True)
    tiled_layers.extend([{'type': 'objectgroup', 'name': '碰撞', 'visible': False, 'objects': collision_objects},
                         {'type': 'objectgroup', 'name': '建筑空间与门洞', 'visible': False, 'objects': geometry_objects}])
    save(output/'stoneford.tmj', town.base_map(width, height, tiled_layers, [{
         'firstgid': 1, 'name': '原版导出素材图集', 'tilewidth': 8, 'tileheight': 8,
         'tilecount': max(tile_cache)+1, 'columns': 8, 'image': 'assets/atlas.png',
         'imagewidth': atlas.width, 'imageheight': atlas.height}]))
    save(output/'native-consumption-report.json', {'status': 'pass', 'projectSha256': art_source.sha(output/'project.json'),
         'originalSprites': len(source_audit['tiles']), 'placedTiles': count, 'nativeLayers': len(document['layers']),
         'tiledLayers': len(tiled_layers),
         'allPlacedTilesUseOriginalBaseSources': True, 'originalInputsUnchanged': True,
         'maximumCanvasRoundTripChannelDifference': overview_difference, 'unityVerified': False})
    print(json.dumps({'status': 'pass', 'output': str(output), 'placements': count,
                      'layers': len(tiled_layers), 'buildings': len(buildings)}, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['prepare', 'export'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--input', type=Path)
    parser.add_argument('--assets-source', type=Path)
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--node-modules')
    args = parser.parse_args()
    if args.command == 'prepare':
        prepare(args.output.resolve())
    else:
        if args.input is None or args.assets_source is None:
            parser.error('export必须指定--input原引擎结果目录和--assets-source原素材准备目录')
        export_world(args.input.resolve(), args.assets_source.resolve(), args.output.resolve(), args.verify, args.node_modules)


if __name__ == '__main__':
    main()
