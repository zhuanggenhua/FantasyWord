#!/usr/bin/env python3
"""抽取锁定场景的真实基础地面与 Grass 覆盖层，输出只能在仓库外。

Dirt 按作者 RuleTile 的 Fixed/Single 首个匹配规则求值，再逐格核对场景缓存。
依据锁定 packages-lock 的 Unity 2D Tilemap Extras 6.0.1 RuleTile.cs。
负责基础地面、映射覆盖和已求值的来源10/20装饰，不复制图片。
"""
import argparse
from collections import Counter
from pathlib import Path
import re
import struct
import subprocess
import yaml
from extract_clickmovetest_rules import SOURCE, SCENE, git, get_document, require, xyz, expect_rectangular_grid, write_local
from extract_clickmovetest_elements import tile_cells

ROOT = 'Assets/Art/KrishnaPalacio/MINIFANTASY - Forgotten Plains/'
DIRT = ROOT + 'Tile Palettes/Rule Tiles/Dirt.asset'
GRASS = ROOT + 'Tile Palettes/Standard Tiles/Ground/Cliff5_Minifantasy_ForgottenPlainsTiles_239.asset'
DIRT_GUID = '5923a633d5be61b4da07719a51278bda'
GRASS_GUID = 'ee44f04c19e463d48a8796f568a766fa'
TEXTURES = {'49ebf7de40457d84495983a6734b2c68': 'Tiles.png', '57153bc98c84b584394a27c7ed1998ae': 'RedRuleTiles.png'}
VEGETATION = 'Assets/GameData/GameCore/SurfaceTiles/ForgottenPlainsVegetation/'
LAKE = ROOT + 'Tile Palettes/Animated Tiles/Lake/'
LAKE_NUMBERS = (*range(1,12),13,14)
TILES_GUID = '49ebf7de40457d84495983a6734b2c68'
FIXED_DECORATIONS = {10: {
    'Standard Tiles/Ground/Dirt8_Minifantasy_ForgottenPlainsTiles_74':1,
    'Standard Tiles/Ground/Dirt19_Minifantasy_ForgottenPlainsTiles_4':7,
    'Standard Tiles/Ground/Dirt5_Minifantasy_ForgottenPlainsTiles_46':1,
    'Standard Tiles/Ground/Dirt2_Minifantasy_ForgottenPlainsTiles_21':1,
    'Standard Tiles/Cliffs/Cliff34_Minifantasy_ForgottenPlainsTiles_510':1,
    'Rule Tiles/CobblestoneGrass 3':4,
}, 20: {
    'Standard Tiles/Cliffs/CliffShadow4_Minifantasy_ForgottenPlainsTilesShadows_3':1,
    'Rule Tiles/CliffStairs':3,
}}
COMBO_RULE = ROOT + 'Tile Palettes/Rule Tiles/CobblestoneGrass Combo.asset'
COMBO_GUID = '7bfd441c8ff48e045b04a3a8ed4ac2d0'
COMBO_COUNTS = {10:59, 20:6}
CLIFF_SHADOWS_GUID = '1389a4518cee0534ea58db4eb226c532'
CLIFF_SHADOWS = {CLIFF_SHADOWS_GUID: 'TilesShadows.png'}
WATER_RULE = ROOT + 'Tile Palettes/Rule Tiles/LakeGrass.asset'
WATER_GUID = 'c637942d78ef0e54ab3507528f1f9095'
WATER_MATERIAL = [{'fileID':2100000,'guid':'468767637290477d8433734e8bf00901','type':2}]
PROPS = {'be785b53e8101134cb49e391918a7a82': 'Props.png',
         'da4d732596845594e9b99bf9488ee15f': 'PropsShadow.png'}
DEFAULT_TILE_MATERIAL = [{'fileID':10754,'guid':'0000000000000000f000000000000000','type':0}]
SPRITE_LIT_MATERIAL = [{'fileID':2100000,'guid':'a97c105638bdf8b4a8650670310a4cd3','type':2}]
IDENTITY = {f'e{y}{x}': int(x == y) for y in range(4) for x in range(4)}
WHITE = dict(r=1, g=1, b=1, a=1)


def read(checkout, path):
    return git(checkout, 'show', f'{SOURCE}:{path}')


def first_fixed_rule(rule_asset, cell, authored_cells, tile_guid, output):
    """执行当前锁定的四边形网格 Fixed Rule，不猜随机或旋转分支。"""
    for rule in rule_asset['m_TilingRules']:
        require(rule['m_RuleTransform'] == 0 and (output is None or rule['m_Output'] == output), '不是指定的固定规则输出')
        raw = bytes.fromhex(rule['m_Neighbors'] or '')
        require(len(raw) % 4 == 0, '邻接字节损坏')
        neighbors = struct.unpack('<' + 'i' * (len(raw) // 4), raw)
        positions = rule['m_NeighborPositions'] or []
        # 原 RuleMatches 使用两数组长度的最小值；Grass 末规则保留 8 位置但无邻接。
        require(all(n in (0,1,2) for n in neighbors), '邻接类型不支持')
        for neighbor, offset in zip(neighbors, positions):
            other = authored_cells.get(tuple(a+b for a,b in zip(cell, xyz(offset))), {})
            same = other.get('guid') == tile_guid
            if (neighbor == 1 and not same) or (neighbor == 2 and same):
                break
        else:
            return rule
    return None


def resolve_fixed_tile_rule(rule_asset, cell, authored_cells, tile_guid):
    rule = first_fixed_rule(rule_asset,cell,authored_cells,tile_guid,0)
    return rule['m_Sprites'][0] if rule is not None else rule_asset['m_DefaultSprite']


def extract_water_base(checkout, scene, sprites, used):
    """仅原水材质无反射贡献的底图，不合成倒影或加入物理。"""
    mat = get_document(read(checkout,'Assets/Settings/WaterReflection/WaterReflectionTilemap.mat'),2100000,'Material')
    require(mat['m_Shader']['guid'] == 'bdc4b0e1ab7a518468bac3f34b5f64ac'
            and next(x['_Color'] for x in mat['m_SavedProperties']['m_Colors'] if '_Color' in x) == WHITE,
            '原水材质不是白色不调色底图')
    go = get_document(scene,2080991800,'GameObject')
    transform = get_document(scene,2080991801,'Transform')
    require(go['m_IsActive'] == 1 and transform['m_GameObject']['fileID'] == 2080991800
            and xyz(transform['m_LocalPosition']) == [0,0,0] and xyz(transform['m_LocalScale']) == [1,1,1]
            and transform['m_LocalRotation'] == dict(x=0,y=0,z=0,w=1)
            and transform['m_Father']['fileID'] == 1148507050, '原水层变换变化')
    tilemap_id = 2080991806
    water = get_document(scene,tilemap_id,'Tilemap')
    renderer = get_document(scene,2080991805,'TilemapRenderer')
    require(water['m_GameObject']['fileID'] == renderer['m_GameObject']['fileID'] == 2080991800
            and xyz(water['m_TileAnchor']) == [.5,.5,0] and water['m_TileOrientationMatrix'] == IDENTITY
            and water['m_TileOrientation'] == 0 and water['m_AnimationFrameRate'] == 1 and water['m_Color'] == WHITE
            and renderer['m_Enabled'] == 1 and renderer['m_SortingLayerID'] == 0 and renderer['m_SortingOrder'] == -9
            and renderer['m_Mode'] == renderer['m_SortOrder'] == renderer['m_MaskInteraction'] == 0
            and renderer['m_Materials'] == WATER_MATERIAL, '原水层的 Tilemap 或渲染字段变化')
    cells = tile_cells(scene,tilemap_id)
    animated = {tuple(xyz(a['first'])):a['second'] for a in water['m_AnimatedTiles']}
    require(len(cells) == len(animated) == len(water['m_AnimatedTiles']) == 87
            and animated.keys() == cells.keys() and not (cells.keys() & tile_cells(scene,1835126662).keys())
            and all(r['guid']==WATER_GUID and r['fileID']==11400000 for r in cells.values()),
            '原水域不是锁定的动画格或与同排序草重叠')
    raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout,WATER_RULE))
    tile = get_document(raw,11400000,'MonoBehaviour')
    require(yaml.safe_load(read(checkout,WATER_RULE+'.meta'))['guid'] == WATER_GUID
            and tile['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231'
            and all(r['m_Output'] == 2 and r['m_RuleTransform'] == r['m_RandomTransform'] == 0
                    and r['m_MinAnimationSpeed'] == r['m_MaxAnimationSpeed'] == 1
                    and r['m_GameObject']['fileID'] == 0 and len(r['m_Sprites']) == 2 for r in tile['m_TilingRules']),
            '原水域作者资产不是定速两帧 Fixed/Animation')
    rows, counts = [], Counter()
    for entry in water['m_Tiles']:
        cell, data = tuple(xyz(entry['first'])), entry['second']
        rule = first_fixed_rule(tile,cell,cells,WATER_GUID,2)
        require(rule is not None,'原水域未匹配动画规则')
        sequence = rule['m_Sprites']
        cached = animated[cell]
        require(sequence == cached['m_AnimatedSprites'] and cached['m_AnimationSpeed'] == 1
                and cached['m_AnimationTimeOffset'] == cached['m_Flags'] == 0,
                '原水域缓存动画帧序或速率变化')
        # RuleTile.GetTileData chooses frames[0], unlike standalone AnimatedTile.
        sprite_index = data['m_TileSpriteIndex']
        counts[sprite_index] += 1
        require(sequence[0] == water['m_TileSpriteArray'][sprite_index]['m_Data']
                and water['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data'] == IDENTITY
                and water['m_TileColorArray'][data['m_TileColorIndex']]['m_Data'] == WHITE
                and data['m_TileObjectToInstantiateIndex'] == 65535, '原水格缓存不是已求值的单位变换')
        keys = [f"{f['guid']}:{f['fileID']}" for f in sequence]
        require(all(f['guid']==TILES_GUID for f in sequence)
                and all(sprites[k]['rect'][2:] == [8,8] and sprites[k]['pivot'] == [.5,.5] for k in keys),
                '水域原图集或枢轴变化')
        used.update(keys)
        rows.append({'cell':list(cell),'frames':keys})
    require(all(counts[i]==r['m_RefCount'] for i,r in enumerate(water['m_TileSpriteArray'])),
            '原水格精灵引用计数不符')
    return {'tilemap_id':tilemap_id,'frames_per_second':1,'sorting_order':-9,'rows':rows}


def fixed_decorations(checkout, source_id):
    tiles = {}
    for name, count in FIXED_DECORATIONS[source_id].items():
        path = ROOT + 'Tile Palettes/' + name + '.asset'
        guid = yaml.safe_load(read(checkout, path + '.meta'))['guid']
        raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout, path))
        tile = get_document(raw, 11400000, 'MonoBehaviour')
        require(guid not in tiles and tile['m_Name'] == name.split('/')[-1], '固定装饰作者资产不符')
        rule_tile = name.startswith('Rule Tiles/')
        if rule_tile:
            require(tile['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231'
                    and tile['m_DefaultGameObject']['fileID'] == 0
                    and all(r['m_RuleTransform'] == r['m_Output'] == r['m_RandomTransform'] == 0
                            and r['m_GameObject']['fileID'] == 0 for r in tile['m_TilingRules']),
                    '原石路或楼梯不是固定单图规则')
        else:
            require(tile['m_Script'] == {'fileID':13312,'guid':'0000000000000000e000000000000000','type':0}
                    and tile['m_Transform'] == IDENTITY and tile['m_Color'] == WHITE
                    and tile['m_InstancedGameObject']['fileID'] == 0, '不是原普通静态 Tile')
        tiles[guid] = (tile, count, rule_tile)
    return tiles


def read_combo_rule(checkout, sprites):
    # 只有这两层的锁定作者布局使用此缓存；不以 Godot 噪声近似 Unity 选图。
    raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout, COMBO_RULE))
    tile = get_document(raw, 11400000, 'MonoBehaviour')
    rules = tile['m_TilingRules']
    require(yaml.safe_load(read(checkout, COMBO_RULE+'.meta'))['guid'] == COMBO_GUID
            and tile['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231'
            and tile['m_DefaultGameObject']['fileID'] == 0
            and len(rules) == 15, '原石草混合 RuleTile 身份或规则数量变化')
    for index, rule in enumerate(rules):
        require(rule['m_Id'] == index and rule['m_Output'] == 1
                and rule['m_RuleTransform'] == rule['m_RandomTransform'] == 0
                and rule['m_PerlinScale'] == (.75 if index == 4 else .5)
                and rule['m_GameObject']['fileID'] == 0 and len(rule['m_Sprites']) == 3,
                '原石草混合规则不是锁定的固定变换、三选一输出')
        keys = [f"{item['guid']}:{item['fileID']}" for item in rule['m_Sprites'] if item['guid'] == TILES_GUID]
        require(len(set(keys)) == 3 and all(k in sprites and sprites[k]['rect'][2:] == [8,8]
                    and sprites[k]['pivot'] == [.5,.5] for k in keys), '原随机候选不再是锁定原图集的中心 8 像素格')
    return tile


def resolve_vegetation(checkout, reference):
    guid = reference['guid']
    require(reference['fileID'] == 11400000 and re.fullmatch(r'[0-9a-f]{32}', guid), '未知植被 Tile 引用')
    prefix = f'{SOURCE}:{VEGETATION}'
    files = git(checkout, 'grep', '-zl', f'^guid: {guid}$', SOURCE, '--', VEGETATION).rstrip('\0').split('\0')
    require(len(files) == 1 and files[0].startswith(prefix) and files[0].endswith('.asset.meta'), '植被引用不唯一')
    tile = get_document(read(checkout, files[0].split(':', 1)[1].removesuffix('.meta')), 11400000, 'MonoBehaviour')
    require(tile['m_EditorClassIdentifier'] == 'UnityEngine.dll::UnityEngine.Tilemaps.Tile'
            and tile['m_Script'] == {'fileID':13312,'guid':'0000000000000000e000000000000000','type':0}
            and tile['m_Transform'] == IDENTITY and tile['m_Color'] == WHITE and tile['m_Flags'] == 0
            and tile['m_ColliderType'] == 0 and tile['m_InstancedGameObject']['fileID'] == 0, '植被不是原普通静态 Tile')
    return tile['m_Sprite']


def validate_vegetation_render_state(checkout, scene):
    # 锁定几何与场景材质输入；不从静态设置断言完整 URP 帧像素已一致。
    light = get_document(scene, 619394801, 'MonoBehaviour')
    light_guid = '073797afb82c5a1438f328866b10b3f0'
    require(scene.count(light_guid) == 1 and light['m_Script']['guid'] == light_guid
            and light['m_Enabled'] == 1 and light['m_LightType'] == 4 and light['m_BlendStyleIndex'] == 0
            and light['m_Color'] == WHITE and light['m_Intensity'] == 1
            and str(light['m_ApplyToSortingLayers']).zfill(8) == '00000000'
            and light['m_NormalMapQuality'] == 2 and light['m_ShadowsEnabled'] == 0, '未知植被光照')
    renderer = read(checkout, 'Assets/Settings/Renderer2D.asset')
    require(re.search(r'(?m)^  m_HDREmulationScale: 1$', renderer)
            and re.search(r'(?m)^  - name: Multiply\n    maskTextureChannel: 0\n    blendMode: 1$', renderer), '未知植被 Renderer2D 混合样式')


def lake_animations(checkout):
    assets = {}
    for number in LAKE_NUMBERS:
        name = f'LakeGrass {number}'
        path = LAKE + name + '.asset'
        meta = yaml.safe_load(read(checkout, path + '.meta'))
        tile = get_document(read(checkout, path),11400000,'MonoBehaviour')
        require(tile['m_Name'] == name
                and tile['m_Script'] == {'fileID':11500000,'guid':'13b75c95f34a00d4e8c04f76b73312e6','type':3}
                and tile['m_MinSpeed'] == tile['m_MaxSpeed'] == 1
                and tile['m_AnimationStartTime'] == tile['m_AnimationStartFrame'] == tile['m_TileColliderType'] == 0,
                '不是锁定 AnimatedTile 6.0.1 的无偏移 LakeGrass')
        frames = tile['m_AnimatedSprites']
        require(len(frames) == 2 and frames[0] != frames[1] and all(f['guid'] == TILES_GUID for f in frames), 'LakeGrass 帧来源不符')
        require(meta['guid'] not in assets, 'LakeGrass 资产重复')
        assets[meta['guid']] = frames
    return assets


def extract_shadow_layers(checkout, scene, sprites, used, nav):
    root = ROOT + 'Tile Palettes/Standard Tiles/Cliffs/'
    nav_ids = {r['m_tilemap']['fileID'] for r in nav['m_surfaceLayerSources']}
    # 同一锁定场景，两层常驻装饰都不是地表状态映射。
    result, tile_sprites = [], {}
    for tile_id, order, count in ((1712506432,-7,35),(1850812192,-1,7)):
        tilemap = get_document(scene,tile_id,'Tilemap')
        renderer = get_document(scene,tile_id-1,'TilemapRenderer')
        owner_id = tilemap['m_GameObject']['fileID']
        owner = get_document(scene,owner_id,'GameObject')
        cells = tile_cells(scene,tile_id)
        require(tile_id not in nav_ids and owner['m_IsActive'] == 1
                and [c['component']['fileID'] for c in owner['m_Component']] == [tile_id-2,tile_id,tile_id-1]
                and len(cells) == count and not tilemap['m_AnimatedTiles']
                and tilemap['m_Color'] == WHITE and tilemap['m_TileOrientationMatrix'] == IDENTITY
                and tilemap['m_TileOrientation'] == renderer['m_SortingLayerID'] == renderer['m_Mode'] == 0
                and renderer['m_GameObject']['fileID'] == owner_id and renderer['m_Enabled'] == 1
                and renderer['m_SortingOrder'] == order and renderer['m_MaskInteraction'] == renderer['m_SortOrder'] == 0
                and renderer['m_Materials'] == DEFAULT_TILE_MATERIAL, '原两层静态阴影的对象或渲染配置变化')
        rows, indexes = [], Counter()
        for entry in tilemap['m_Tiles']:
            cell,data = tuple(xyz(entry['first'])),entry['second']
            ref = cells[cell]
            key = ref['guid']
            require(ref['fileID'] == 11400000, '阴影 Tile 的身份不符')
            if key not in tile_sprites:
                paths = git(checkout,'grep','-zl',f'^guid: {key}$',SOURCE,'--',root).rstrip('\0').split('\0')
                require(len(paths)==1 and paths[0].endswith('.asset.meta'), '原阴影 Tile 不唯一')
                asset = get_document(read(checkout,paths[0].split(':',1)[1].removesuffix('.meta')),11400000,'MonoBehaviour')
                require(asset['m_Script'] == {'fileID':13312,'guid':'0000000000000000e000000000000000','type':0}
                        and asset['m_Transform'] == IDENTITY and asset['m_Color'] == WHITE and asset['m_Flags'] == 1
                        and asset["m_ColliderType"] == 1 and asset["m_InstancedGameObject"]['fileID'] == 0,
                        '原阴影静态 Tile 的 Sprite 形状或实例字段变化')
                tile_sprites[key] = asset['m_Sprite']
            sprite = tile_sprites[key]
            index = data['m_TileSpriteIndex']
            indexes[index] += 1
            sprite_key = f"{sprite['guid']}:{sprite['fileID']}"
            require(sprite == tilemap['m_TileSpriteArray'][index]['m_Data']
                    and sprite['guid'] == CLIFF_SHADOWS_GUID and sprite_key in sprites
                    and sprites[sprite_key]['rect'][2:] == [8,8] and sprites[sprite_key]['pivot'] == [.5,.5]
                    and tilemap['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data'] == IDENTITY
                    and tilemap['m_TileColorArray'][data['m_TileColorIndex']]['m_Data'] == WHITE
                    and data['m_TileObjectToInstantiateIndex'] == 65535 and data['m_AllTileFlags'] == 1073741825,
                    '阴影瓦片未匹配作者图集与场景缓存')
            used.add(sprite_key)
            rows.append({'cell':list(cell),'sprite':sprite_key})
        require(all(indexes[i]==x['m_RefCount'] for i,x in enumerate(tilemap['m_TileSpriteArray'])),
                '原阴影精灵引用数不符')
        result.append({'tilemap_id':tile_id,'sorting_order':order,'rows':rows})
    return result


def extract_pillars(checkout, scene, sprites, used):
    variants = ('tall1','tall2','tall3','medium1','medium2','medium3','medium4','short1','short2')
    pillar_script = read(checkout, ROOT + 'Scripts/PropVariants/FP_Pillar.cs')
    require(all(re.search(rf"case PillarSelection\.{name[0].upper()+name[1:]}:\s+selectedSprite = {name};\s+selectedShadow = shadow{name[0].upper()+name[1:]};",pillar_script)
                for name in variants), '原柱子九种 OnValidate 分支变化')

    enum_body = re.search(r'private enum PillarSelection\s*\{([^}]+)\}',pillar_script,re.S)
    require(enum_body is not None and tuple(x.strip().lower() for x in enum_body[1].split(',') if x.strip())==variants,
            '原柱子变体索引顺序变化')

    def identity_transform(t, parent):
        return t['m_Father']['fileID']==parent and xyz(t['m_LocalScale'])==[1,1,1] and t['m_LocalRotation']==dict(x=0,y=0,z=0,w=1)

    for node, parent in ((1951579796,197348023),(197348023,1148507050),(1148507050,6951707),(6951707,900000102),(900000102,0)):
        t = get_document(scene,node,'Transform')
        owner = get_document(scene,t['m_GameObject']['fileID'],'GameObject')
        require(identity_transform(t,parent) and xyz(t['m_LocalPosition'])==[0,0,0] and owner['m_IsActive']==1
                and not any(re.search(rf'^--- !u!210 &{c["component"]["fileID"]}\b',scene,re.M) for c in owner['m_Component']),
                '原柱父链或排序组发生变化')
    root = get_document(scene,1951579796,'Transform')

    def sprite_row(renderer_id, owner, ref, order, atlas):
        r=get_document(scene,renderer_id,'SpriteRenderer')
        key=f"{ref['guid']}:{ref['fileID']}"
        require(r['m_GameObject']['fileID']==owner and r['m_Enabled']==1 and r['m_Sprite']==ref
                and r['m_Materials']==DEFAULT_TILE_MATERIAL and r['m_Color']==WHITE
                and r['m_SortingLayerID']==r['m_SpriteSortPoint']==r['m_FlipX']==r['m_FlipY']==r['m_DrawMode']==r['m_MaskInteraction']==0
                and r['m_SortingOrder']==order and ref['guid']==atlas and key in sprites,
                '原柱子缓存、选图、翻转或排序方式变化')
        used.add(key)
        return {'renderer_id':renderer_id,'sprite':key,'sorting_order':order}

    result = []
    counts = Counter()
    for child in root['m_Children']:
        node_id = child['fileID']
        t = get_document(scene,node_id,'Transform')
        owner_id=t['m_GameObject']['fileID']
        owner=get_document(scene,owner_id,'GameObject')
        require(re.fullmatch(r'Pillar(?: \(\d+\))?',owner['m_Name']) and owner['m_IsActive']==1
                and owner['m_Layer']==0 and identity_transform(t,1951579796)
                and t['m_LocalPosition']['z']==0 and len(t['m_Children'])==1, '不是锁定的原活跃柱子')
        owner_components=[c['component']['fileID'] for c in owner['m_Component']]
        require(len(owner_components)==4 and owner_components[0]==node_id, '原柱子组件列表变化')
        collider=get_document(scene,owner_components[2],'BoxCollider2D')
        variant=get_document(scene,owner_components[3],'MonoBehaviour')
        require(collider['m_GameObject']['fileID']==owner_id and collider['m_Enabled']==1
                and collider['m_Offset']==dict(x=0,y=0)
                and variant['m_Enabled']==1 and variant['m_GameObject']['fileID']==owner_id
                and variant['m_Script']['guid']=='fcf74fae0478f2e49abe61340164d67c'
                and 0<=variant['selection']<len(variants), '原柱子组件或作者变体变化')
        selection=variant['selection']
        key=variants[selection]
        shadow_id=t['m_Children'][0]['fileID']
        shadow=get_document(scene,shadow_id,'Transform')
        shadow_owner_id=shadow['m_GameObject']['fileID']
        shadow_owner=get_document(scene,shadow_owner_id,'GameObject')
        shadow_components=[c['component']['fileID'] for c in shadow_owner['m_Component']]
        require(identity_transform(shadow,node_id) and xyz(shadow['m_LocalPosition'])==[0,0,0]
                and not shadow['m_Children'] and shadow_owner['m_Name']=='Shadow'
                and shadow_owner['m_IsActive']==1 and shadow_owner['m_Layer']==0
                and len(shadow_components)==2 and shadow_components[0]==shadow_id, '原柱影父子或位置变化')
        result.append({'object_id':owner_id,'collider_id':owner_components[2],'variant':selection,
                       'position':xyz(t['m_LocalPosition'])[:2],
                       'body':sprite_row(owner_components[1],owner_id,variant[key],0,tuple(PROPS)[0]),
                       'shadow':sprite_row(shadow_components[1],shadow_owner_id,variant['shadow'+key[0].upper()+key[1:]],-7,tuple(PROPS)[1])})
        counts[selection]+=1
    require(len(result)==14 and counts==Counter({0:1,1:1,2:2,3:1,4:1,5:1,6:1,7:1,8:5}), '原柱子及变体总数变化')
    return result


def extract_grouped_trees(checkout, scene, sprites, used):
    # 原 Unity 变体选择只在编辑器改变两个 SpriteRenderer；验证缓存而不造新树。
    script = read(checkout,ROOT+'Scripts/PropVariants/FP_Tree.cs')
    enum_body = re.search(r'private enum TreeSelection\s*\{([^}]+)\}',script,re.S)
    variants = ('TreeApples','TreeNoApples')
    require(enum_body is not None and tuple(x.strip() for x in enum_body[1].split(',') if x.strip())==variants
            and all(re.search(rf"case TreeSelection\.{name}:\s+selectedSprite = {name[0].lower()+name[1:]};\s+selectedShadow = shadow{name};",script)
                    for name in variants), '原树种变体枚举或选择变化')

    def checked_transform(node, parent):
        t = get_document(scene,node,'Transform')
        owner_id = t['m_GameObject']['fileID']
        owner = get_document(scene,owner_id,'GameObject')
        require(owner['m_IsActive']==1 and owner['m_Layer']==0 and t['m_Father']['fileID']==parent
                and xyz(t['m_LocalScale'])==[1,1,1] and t['m_LocalRotation']==dict(x=0,y=0,z=0,w=1)
                and t['m_LocalPosition']['z']==0, '原树父链或 Transform 变化')
        return t,owner,[c['component']['fileID'] for c in owner['m_Component']]

    for node,parent in ((1286769017,1325276966),(1325276966,197348023),(197348023,1148507050),
                        (1148507050,6951707),(6951707,900000102),(900000102,0)):
        t,_,parts = checked_transform(node,parent)
        require(xyz(t['m_LocalPosition'])==[0,0,0]
                and not any(re.search(rf'^--- !u!210 &{n}\b',scene,re.M) for n in parts),
                '原树素组不应存在额外根排序或平移')
    root = get_document(scene,1286769017,'Transform')

    def render_row(renderer_id, owner_id, ref, order, atlas):
        r=get_document(scene,renderer_id,'SpriteRenderer')
        key=f"{ref['guid']}:{ref['fileID']}"
        require(r['m_GameObject']['fileID']==owner_id and r['m_Enabled']==1 and r['m_Sprite']==ref
                and r['m_Materials']==DEFAULT_TILE_MATERIAL and r['m_Color']==WHITE
                and r['m_SortingLayerID']==r['m_SpriteSortPoint']==r['m_FlipX']==r['m_FlipY']==r['m_DrawMode']==r['m_MaskInteraction']==0
                and r['m_SortingOrder']==order and ref['guid']==atlas and key in sprites and sprites[key]['pivot']==[.5,.5],
                '原树 Sprite 缓存、枢轴或组内排序变化')
        used.add(key)
        return {'renderer_id':renderer_id,'sprite':key,'inner_order':order}

    output, orders, selections, casters = [], Counter(), Counter(), 0
    for ref in root['m_Children']:
        group_id=ref['fileID']
        group,owner,parts=checked_transform(group_id,1286769017)
        require(re.fullmatch(r'Tree(?: \(\d+\))?',owner['m_Name']) and len(parts)==2
                and parts[0]==group_id and len(group['m_Children'])==1,'原树组层级变化')
        settings=get_document(scene,parts[1],'SortingGroup')
        require(settings['m_Enabled']==1 and settings['m_GameObject']==group['m_GameObject']
                and settings['m_SortingLayerID']==settings['m_SortAtRoot']==settings['m_Sort3DAs2D']==0,
                '原树 SortingGroup 不再使用普通 Default 分组')
        order=settings['m_SortingOrder']
        body_id=group['m_Children'][0]['fileID']
        body,body_owner,body_parts=checked_transform(body_id,group_id)
        bridge=body_parts[1]==987751660
        require(body_owner['m_Name']=='Tree' and body_parts[0]==body_id and len(body_parts)==(5 if bridge else 4)
                and xyz(body['m_LocalPosition'])==[0,0,0] and len(body['m_Children'])==(2 if bridge else 1),
                '原树体局部 Transform 或组件变化')
        variant=get_document(scene,body_parts[3],'MonoBehaviour')
        collider=get_document(scene,body_parts[2],'BoxCollider2D')
        require(collider['m_GameObject']==body['m_GameObject'] and collider['m_Enabled']==1
                and variant['m_GameObject']==body['m_GameObject'] and variant['m_Enabled']==1
                and variant['m_Script']['guid']=='6c6f80182aefb134a991b24abd3c00b9'
                and variant['selection'] in (0,1),'原树变体或碰撞组件身份变化')
        selection=variant['selection']
        name=variants[selection]
        shadow_id=next((c['fileID'] for c in body['m_Children'] if c['fileID']!=1387362305),0)
        shadow,shadow_owner,shadow_parts=checked_transform(shadow_id,body_id)
        require(shadow_owner['m_Name']=='Shadow' and len(shadow_parts)==2 and shadow_parts[0]==shadow_id
                and xyz(shadow['m_LocalPosition'])==[-.125,0,0] and not shadow['m_Children'],'原树阴影局部位置变化')
        if bridge:
            anchor,_,_=checked_transform(1387362305,body_id)
            caster=get_document(scene,body_parts[4],'MonoBehaviour')
            require(body_parts[4]==987751661 and caster['m_GameObject']==body['m_GameObject']
                    and caster['m_Enabled']==1 and caster['m_sourceRenderers']==[{'fileID':987751660}]
                    and caster['m_equipmentRenderer']['fileID']==0 and caster['m_reflectionAnchor']['fileID']==1387362305
                    and (caster['m_verticalScale'],caster['m_skew'],caster['m_waterReach'],caster['m_disableWhileSwimming'])==(.65,-.35,.5,1)
                    and xyz(group['m_LocalPosition'])==[-.4375,-8.1875,0] and xyz(anchor['m_LocalPosition'])==[0,-1.5625,0],
                    '原单棵树反射见证条件变化')
            casters+=1
        orders[order]+=1
        selections[selection]+=1
        output.append({'group_id':group['m_GameObject']['fileID'],'collider_id':body_parts[2],
                       'position':xyz(group['m_LocalPosition'])[:2],'order':order,'reflection':bridge,
                       'body':render_row(body_parts[1],body['m_GameObject']['fileID'],variant[name[0].lower()+name[1:]],0,tuple(PROPS)[0]),
                       'shadow':render_row(shadow_parts[1],shadow['m_GameObject']['fileID'],variant['shadow'+name],-7,tuple(PROPS)[1])})
    require(orders==Counter({0:5,1:3,2:2,3:3}) and selections==Counter({0:3,1:10}) and casters==1,
            '原树排序、变体或唯一反射源数量变化')
    return output


def extract_low_props(checkout, scene, sprites, used):
    """Unbound decoration: OnValidate chooses exact cached body + shadow.
    The two renderers retain their *independent* original sorting orders.
    """
    def child(node, parent):
        t = get_document(scene,node,'Transform')
        owner_id = t['m_GameObject']['fileID']
        owner = get_document(scene,owner_id,'GameObject')
        parts = [c['component']['fileID'] for c in owner['m_Component']]
        require(owner['m_IsActive']==1 and owner['m_Layer']==0 and parts[0]==node
                and t['m_Father']['fileID']==parent and xyz(t['m_LocalScale'])==[1,1,1]
                and t['m_LocalRotation']==dict(x=0,y=0,z=0,w=1)
                and t['m_LocalPosition']['z']==0, '原小型植被的父链、层级或坐标变化')
        return t,owner_id,owner['m_Name'],parts

    def part(renderer_id, owner_id, ref, order, atlas, offset):
        r = get_document(scene,renderer_id,'SpriteRenderer')
        key = f"{ref['guid']}:{ref['fileID']}"
        require(r['m_GameObject']['fileID']==owner_id and r['m_Enabled']==1
                and r['m_Sprite']==ref and r['m_Materials']==DEFAULT_TILE_MATERIAL and r['m_Color']==WHITE
                and r['m_SortingLayerID']==r['m_SpriteSortPoint']==r['m_FlipX']==r['m_FlipY']==r['m_DrawMode']==r['m_MaskInteraction']==0
                and r['m_SortingOrder']==order and ref['guid']==atlas and key in sprites,
                '原小型植被精灵、材质或独立排序变化')
        used.add(key)
        return {'renderer_id':renderer_id,'sprite':key,'sorting_order':order,'offset':offset}

    for node,parent in ((1325276966,197348023),(197348023,1148507050),(1148507050,6951707),
                        (6951707,900000102),(900000102,0)):
        t,_,_,parts = child(node,parent)
        require(xyz(t['m_LocalPosition'])==[0,0,0]
                and not any(re.search(rf'^--- !u!210 &{n}\b',scene,re.M) for n in parts),
                '原小型植被父链不能引入其他坐标或排序')
    configs = (
        ('Creeper','Creepers',2093145030,'eb7b65bf44e71cc4bab72e04e8f61e1e',[0,.0625],[2,3,3,4,2,2,2,1]),
        ('Cattail','Cattails',1768259134,'53fcedef8c1326b4c8c22b0d914cce29',[-.125,0],[6,7]),
    )
    rows = []
    for kind, root_name, root_id, script_guid, shadow_offset, counts in configs:
        root,_,name,parts = child(root_id,1325276966)
        require(name==root_name and len(parts)==1 and xyz(root['m_LocalPosition'])==[0,0,0],
                '原小型植被根节点不再是纯 Transform')
        script = read(checkout,ROOT+f'Scripts/PropVariants/FP_{kind}.cs')
        enum_body = re.search(rf'private enum {kind}Selection\s*\{{([^}}]+)\}}',script,re.S)
        variants = [f'{kind}{i+1}' for i in range(len(counts))]
        require(enum_body is not None and [x.strip() for x in enum_body[1].split(',') if x.strip()]==variants
                and re.findall(r'\bvoid\s+(\w+)\s*\(',script)==['OnValidate']
                and 'GetComponent<SpriteRenderer>().sprite = selectedSprite;' in script
                and 'transform.Find("Shadow").GetComponent<SpriteRenderer>().sprite = selectedShadow;' in script
                and all(re.search(rf'case {kind}Selection\.{n}:\s+selectedSprite = {n.lower()};\s+selectedShadow = shadow{n};',script)
                        for n in variants), '原小型植被变体选择不再是纯编辑器机制')
        selections, names = Counter(), set()
        for ref in root['m_Children']:
            body_id=ref['fileID']
            body,owner_id,name,body_parts=child(body_id,root_id)
            require(len(body_parts)==3 and len(body['m_Children'])==1,
                    '原小型植被存在额外组件或子节点')
            names.add(name)
            v=get_document(scene,body_parts[2],'MonoBehaviour')
            require(v['m_GameObject']['fileID']==owner_id and v['m_Enabled']==1
                    and v['m_Script']['guid']==script_guid and 0<=v['selection']<len(variants),
                    '原小型植被组件身份或变体变化')
            selection=v['selection']
            selections[selection]+=1
            variant=variants[selection]
            shadow,sid,sname,shadow_parts=child(body['m_Children'][0]['fileID'],body_id)
            require(sname=='Shadow' and len(shadow_parts)==2 and not shadow['m_Children']
                    and xyz(shadow['m_LocalPosition'])==shadow_offset+[0],
                    '原小型植被阴影层级或偏移变化')
            exceptional=kind=='Cattail' and name=='Cattail (11)'
            require(exceptional==(owner_id==1901380167), '原香蒲的特殊低排序身份变化')
            rows.append({'object_id':owner_id,'kind':kind,'position':xyz(body['m_LocalPosition'])[:2],
                         'selection':selection,
                         'body':part(body_parts[1],owner_id,v[variant.lower()],-1 if exceptional else 0,tuple(PROPS)[0],[0,0]),
                         'shadow':part(shadow_parts[1],sid,v['shadow'+variant],-7,tuple(PROPS)[1],shadow_offset)})
        require(selections==Counter(dict(enumerate(counts)))
                and names=={kind}|{f'{kind} ({i})' for i in range(1,sum(counts))},
                '原小型植被实例数、命名或变体分布变化')
    require(len(rows)==len({r['object_id'] for r in rows})==32, '原小型植被身份应为32个并互不重复')
    return rows


def validate_wall_layer(scene, nav, tile_id, count, order):
    renderer_id, owner_id = tile_id-1, tile_id-6
    tilemap = get_document(scene,tile_id,'Tilemap')
    renderer = get_document(scene,renderer_id,'TilemapRenderer')
    owner = get_document(scene,owner_id,'GameObject')
    cells = tile_cells(scene,tile_id)
    require(tile_id not in {r['m_tilemap']['fileID'] for r in nav['m_surfaceLayerSources']}
            and [c['component']['fileID'] for c in owner['m_Component']]
                == [tile_id-5,tile_id,renderer_id,tile_id-2,tile_id-3,tile_id-4]
            and owner['m_IsActive']==1 and tilemap['m_GameObject']['fileID']==renderer['m_GameObject']['fileID']==owner_id
            and len(cells)==count and tilemap['m_Color']==WHITE and tilemap['m_TileOrientationMatrix']==IDENTITY
            and not tilemap['m_AnimatedTiles']
            and tilemap['m_TileOrientation']==renderer['m_SortingLayerID']==renderer['m_Mode']==renderer['m_MaskInteraction']==renderer['m_SortOrder']==0
            and renderer['m_SortingOrder']==order and renderer['m_Enabled']==1
            and renderer['m_Materials']==DEFAULT_TILE_MATERIAL, '原墙或崖体对象、渲染参数或地表映射变化')
    return tilemap, cells


def extract_wall(checkout, scene, sprites, used, nav, vertical=False):
    if vertical:
        tile_id, guid, name, order = 163064786, '33f5d012cce5ed642a0184adb9d0a80f', 'VerticalWall', -6
        expected_outcomes, expected_choices = [(0,1),(1,4),(0,1)], Counter({0:4,1:7})
        expected_frames = 5
    else:
        tile_id, guid, name, order = 1289053702, 'd8780a9d276c3064fa51d9d48be6586b', 'HorizontalWall', -5
        expected_outcomes, expected_choices = [(0,1)]*13, Counter({0:56})
        expected_frames = 11
    path = ROOT + f'Tile Palettes/Rule Tiles/{name}.asset'
    props_atlas = 'be785b53e8101134cb49e391918a7a82'
    authored = get_document(re.sub(r'(m_Neighbors: )([0-9a-f]+)',r'\1"\2"',read(checkout,path)),11400000,'MonoBehaviour')
    require(yaml.safe_load(read(checkout,path+'.meta'))['guid']==guid
            and authored['m_Script']['guid']=='9d1514134bc4fbd41bb739b1b9a49231'
            and [(r['m_Output'],len(r['m_Sprites'])) for r in authored['m_TilingRules']]==expected_outcomes
            and all(r['m_RuleTransform']==r['m_RandomTransform']==0 and r['m_ColliderType']==1
                    and all(f['guid']==props_atlas for f in r['m_Sprites'])
                    for r in authored['m_TilingRules']), '原墙图集、规则输出或固定变换变化')
    tilemap, cells = validate_wall_layer(scene,nav,tile_id,expected_choices.total(),order)
    require(all(ref=={'fileID':11400000,'guid':guid,'type':2} for ref in cells.values()), '原墙瓦片引用变化')
    indexes, choices, chosen, rows = Counter(), Counter(), set(), []
    for entry in tilemap['m_Tiles']:
        cell, data = tuple(xyz(entry['first'])),entry['second']
        rule = first_fixed_rule(authored,cell,cells,guid,None)
        require(rule is not None, '原墙不能使用未命中的 fallback')
        output = rule['m_Output']
        index = data['m_TileSpriteIndex']
        indexes[index]+=1
        cached = tilemap['m_TileSpriteArray'][index]['m_Data']
        # 原场景此处不改布置；随机中段按第一条原规则验证候选，显示已序列化选图。
        # 运行时不猜 Unity Perlin，也不重算中段。
        sprite = cached if output==1 else rule['m_Sprites'][0]
        key = f"{sprite['guid']}:{sprite['fileID']}"
        require(sprite==cached and sprite in rule['m_Sprites'] and key in sprites
                and sprites[key]['rect'][2:]==[8,8] and sprites[key]['pivot']==[.5,.5]
                and tilemap['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data']==IDENTITY
                and tilemap['m_TileColorArray'][data['m_TileColorIndex']]['m_Data']==WHITE
                and data['m_TileObjectToInstantiateIndex']==65535 and data['m_AllTileFlags']==1073741826, '原墙求值和场景缓存不一致')
        choices[output]+=1
        chosen.add(key)
        used.add(key)
        rows.append({'cell':list(cell),'sprite':key,'mode':'cached_random' if output==1 else 'fixed'})
    require(choices==expected_choices and len(chosen)==expected_frames and all(indexes[i]==x['m_RefCount'] for i,x in enumerate(tilemap['m_TileSpriteArray'])),
            '原墙的选图分布、精灵或引用数变化')
    return {'tilemap_id':tile_id,'sorting_order':order,'rows':rows}


def extract_cliff_bodies(checkout, scene, sprites, used, nav):
    prefix = ROOT + 'Tile Palettes/'
    expected_rules = {'CliffGrass.asset':15,'CliffStairs.asset':11,'CliffWall 1.asset':6}
    tiles, result = {}, []
    for tile_id, count, order in ((2118149258,72,-4),(432984437,47,-3),(147438656,32,-2)):
        tilemap, cells = validate_wall_layer(scene,nav,tile_id,count,order)
        rows, indexes, modes = [], Counter(), Counter()
        for entry in tilemap['m_Tiles']:
            cell, data = tuple(xyz(entry['first'])),entry['second']
            ref = cells[cell]
            guid = ref['guid']
            require(ref['fileID']==11400000 and ref['type']==2, '原崖体 Tile 引用变化')
            if guid not in tiles:
                paths = git(checkout,'grep','-zl',f'^guid: {guid}$',SOURCE,'--',prefix).rstrip('\0').split('\0')
                require(len(paths)==1 and paths[0].endswith('.asset.meta'), '崖体 Tile 身份不唯一')
                path = paths[0].split(':',1)[1].removesuffix('.meta')
                asset = get_document(re.sub(r'(m_Neighbors: )([0-9a-f]+)',r'\1"\2"',read(checkout,path)),11400000,'MonoBehaviour')
                if path.startswith(prefix+'Rule Tiles/'):
                    r = asset['m_TilingRules']
                    require(asset['m_Script']['guid']=='9d1514134bc4fbd41bb739b1b9a49231'
                            and len(r)==expected_rules.get(path.rsplit('/',1)[1])
                            and all(t['m_RuleTransform']==t['m_RandomTransform']==t['m_Output']==0
                                    and t['m_ColliderType']==1 and len(t['m_Sprites']) in (1,2) for t in r),
                            '原崖体固定相邻规则变化')
                    tiles[guid]=(asset,True)
                else:
                    require(path.startswith(prefix+'Standard Tiles/Cliffs/')
                            and asset['m_Script']=={'fileID':13312,'guid':'0000000000000000e000000000000000','type':0}
                            and asset['m_Color']==WHITE and asset['m_Transform']==IDENTITY and asset['m_Flags']==1
                            and asset['m_ColliderType']==1 and asset['m_InstancedGameObject']['fileID']==0,
                            '原崖体普通 Tile 的原配置变化')
                    tiles[guid]=(asset,False)
            asset,is_rule = tiles[guid]
            if is_rule:
                rule = first_fixed_rule(asset,cell,cells,guid,0)
                sprite = rule['m_Sprites'][0] if rule is not None else asset['m_DefaultSprite']
                mode = 'fixed' if rule is not None else 'fixed_default'
            else:
                sprite, mode = asset['m_Sprite'], 'standard'
            index = data['m_TileSpriteIndex']
            indexes[index]+=1
            key=f"{sprite['guid']}:{sprite['fileID']}"
            require(sprite==tilemap['m_TileSpriteArray'][index]['m_Data'] and sprite['guid']==TILES_GUID
                    and key in sprites and sprites[key]['rect'][2:]==[8,8] and sprites[key]['pivot']==[.5,.5]
                    and tilemap['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data']==IDENTITY
                    and tilemap['m_TileColorArray'][data['m_TileColorIndex']]['m_Data']==WHITE
                    and data['m_TileObjectToInstantiateIndex']==65535 and data['m_AllTileFlags']==(1073741826 if is_rule else 1073741825),
                    '原崖体规则选择与场景缓存不一致')
            modes[mode]+=1
            used.add(key)
            rows.append({'cell':list(cell),'sprite':key,'mode':mode})
        require(all(indexes[i]==x['m_RefCount'] for i,x in enumerate(tilemap['m_TileSpriteArray'])), '原崖体精灵引用数变化')
        result.append({'tilemap_id':tile_id,'sorting_order':order,'rows':rows})
    require(len(tiles)==9, '原崖体应使用3种 RuleTile 和6种普通 Tile')
    return result


def extract(checkout):
    scene = read(checkout, SCENE)
    expect_rectangular_grid(scene)
    dirt_raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout, DIRT))
    dirt = get_document(dirt_raw, 11400000, 'MonoBehaviour')
    grass = get_document(read(checkout, GRASS), 11400000, 'MonoBehaviour')
    require(dirt['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231'
            and len(dirt['m_TilingRules']) == 15 and grass['m_Transform'] == IDENTITY
            and grass['m_Color'] == WHITE, '地面作者资产不匹配')
    validate_vegetation_render_state(checkout, scene)
    textures, sprites = {}, {}
    for guid, filename in (TEXTURES | PROPS | CLIFF_SHADOWS).items():
        path = ROOT + ('Sprites/Props/' if guid in PROPS else 'Sprites/Tileset/') + filename
        metadata = yaml.safe_load(read(checkout, path + '.meta'))
        importer = metadata['TextureImporter']
        require(metadata['guid'] == guid and importer['spritePixelsToUnits'] == 8
                and importer['spriteMode'] == 2 and importer['spriteMeshType'] == 1
                and importer['mipmaps']['sRGBTexture'] == 1 and importer['mipmaps']['enableMipMap'] == 0
                and not importer['spriteSheet']['secondaryTextures']
                and importer['textureSettings']['filterMode'] == 0
                and importer['textureSettings']['wrapU'] == 1 and importer['textureSettings']['wrapV'] == 1, '图片元数据不匹配')
        pointer = read(checkout, path)
        digest = re.search(r'^oid sha256:([0-9a-f]{64})$', pointer, re.M)
        require(digest is not None, '缺少原图片 LFS 摘要')
        textures[guid] = {'file': filename, 'sha256': digest[1]}
        for sprite in importer['spriteSheet']['sprites']:
            rect = sprite['rect']
            sprites[f"{guid}:{sprite['internalID']}"] = {'texture': guid,
                'rect': [rect[k] for k in ('x', 'y', 'width', 'height')],
                'pivot': [sprite['pivot'][k] for k in ('x', 'y')], 'ppu': 8}
    upper_guid = 'e41387fb62d13cf40aa1d24ec147cee0'
    upper_raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout, ROOT + 'Tile Palettes/Rule Tiles/Grass.asset'))
    upper = get_document(upper_raw, 11400000, 'MonoBehaviour')
    require(upper['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231', '上层草规则身份不符')
    # 与正式覆盖解析同源，不能因为同层有瓦片就一并当作可燃草。
    nav = get_document(scene, 1148507052, 'MonoBehaviour')
    source = next(row for row in nav['m_surfaceLayerSources'] if row['m_sourceId'] == 20)
    require(source['m_tilemap']['fileID'] == 913349356 and source['m_priority'] == 20
            and [(m['m_tile']['guid'], m['m_coverKind'], m['m_traits']) for m in source['m_surfaceCoverTileMappings']] == [(upper_guid,1,3)], '来源20作者映射变化')
    detail_guid = 'e3e7c5e9438735847b05de88b6910a83'
    detail = get_document(read(checkout, ROOT + 'Tile Palettes/Standard Tiles/Ground/Grass19_Minifantasy_ForgottenPlainsTiles_3.asset'),11400000,'MonoBehaviour')
    require(detail['m_Transform'] == IDENTITY and detail['m_Color'] == WHITE and detail['m_InstancedGameObject']['fileID'] == 0, '来源10标准草配置变化')
    source10 = next(row for row in nav['m_surfaceLayerSources'] if row['m_sourceId'] == 10)
    require(source10['m_tilemap']['fileID'] == 453769794 and source10['m_priority'] == 10
            and [(m['m_tile']['guid'],m['m_coverKind'],m['m_traits']) for m in source10['m_surfaceCoverTileMappings']] == [(upper_guid,1,3),(detail_guid,1,3)], '来源10映射变化')
    vegetation_sprites = {}
    for source_id, tilemap_id, role in ((30,897197880,3),(31,994996502,6)):
        layer = next(row for row in nav['m_surfaceLayerSources'] if row['m_sourceId'] == source_id)
        require(layer['m_tilemap']['fileID'] == tilemap_id and layer['m_priority'] == source_id and layer['m_role'] == role,
                '植被来源身份不符')
        mappings = layer['m_surfaceCoverTileMappings']
        require(len(mappings) == 5 and sorted((m['m_coverKind'],m['m_traits']) for m in mappings) == [(1,3)]*2 + [(5,3)]*3,
                '植被覆盖作者映射变化')
        vegetation_sprites[source_id] = {m['m_tile']['guid']:resolve_vegetation(checkout,m['m_tile']) for m in mappings}
    combo_rule = read_combo_rule(checkout, sprites)
    fixed_decor = {10:fixed_decorations(checkout,10),20:fixed_decorations(checkout,20)}
    for index, source_record in ((10,source10),(20,source)):
        require(not (set(fixed_decor[index]) | {COMBO_GUID}).intersection(m['m_tile']['guid'] for m in source_record['m_surfaceCoverTileMappings']),
                '固定装饰不应属于作者映射草')
    layer10 = get_document(scene,453769791,'GameObject')
    require(layer10['m_IsActive'] == 1 and [c['component']['fileID'] for c in layer10['m_Component']]
            == [453769792,453769794,453769793], '来源10装饰层不应带有物理组件')
    layer20 = get_document(scene,913349350,'GameObject')
    require(layer20['m_IsActive'] == 1 and all(file_id in [c['component']['fileID'] for c in layer20['m_Component']]
            for file_id in (913349351,913349356,913349355)), '来源20不是启用的原装饰层')
    lake_assets = lake_animations(checkout)
    require(not set(lake_assets).intersection(m['m_tile']['guid'] for m in source10['m_surfaceCoverTileMappings']),
            'LakeGrass 不应属于作者映射草')
    used_lake_assets = set()
    layers, used = [], set()
    for tilemap_id, renderer_id, source_id, order, count in ((875022404,875022403,-1,-10,900),(1835126662,1835126661,0,-9,547),(453769794,453769793,10,-8,267),(913349356,913349355,20,-1,13),(897197880,897197881,30,-8,33),(994996502,994996503,31,-7,33)):
        cells = tile_cells(scene, tilemap_id)
        tilemap = get_document(scene, tilemap_id, 'Tilemap')
        renderer = get_document(scene, renderer_id, 'TilemapRenderer')
        is_vegetation = source_id in vegetation_sprites
        if source_id in (10,20,30,31):
            node_id = {10:453769792,20:913349351,30:897197882,31:994996504}[source_id]
            transform = get_document(scene, node_id, 'Transform')
            require(xyz(transform['m_LocalPosition']) == [0,0,0] and xyz(transform['m_LocalScale']) == [1,1,1]
                    and transform['m_LocalRotation'] == dict(x=0,y=0,z=0,w=1)
                    and transform['m_Father']['fileID'] == 1148507050, '不是锁定的装饰或植被变换路径')
        require(len(cells) == count and xyz(tilemap['m_TileAnchor']) == [.5,.5,0] and (source_id == 10 or not tilemap['m_AnimatedTiles']) and tilemap['m_Color'] == WHITE
                and tilemap['m_TileOrientationMatrix'] == IDENTITY and tilemap['m_TileOrientation'] == 0
                and renderer['m_Enabled'] == 1 and renderer['m_SortingLayerID'] == 0
                and renderer['m_SortingOrder'] == order and renderer['m_Mode'] == 0
                and renderer['m_MaskInteraction'] == 0 and renderer['m_SortOrder'] == 0
                and renderer['m_Materials'] == (SPRITE_LIT_MATERIAL if is_vegetation else DEFAULT_TILE_MATERIAL),
                '不是锁定的原地面层材质与排序')
        animated = {tuple(xyz(a['first'])):a['second'] for a in tilemap['m_AnimatedTiles']}
        if source_id == 10:
            require(len(animated) == len(tilemap['m_AnimatedTiles']) == 35 and tilemap['m_AnimationFrameRate'] == 1,
                    '湖岸原动画格数量或 Tilemap 帧率变化')
        rows, indexes, animated_rows, static_rows, static_counts = [], Counter(), [], [], Counter()
        combo_count = 0
        for entry in tilemap['m_Tiles']:
            cell, data = tuple(xyz(entry['first'])), entry['second']
            ref = cells[cell]
            indexes[data['m_TileSpriteIndex']] += 1
            is_lake = source_id == 10 and cell in animated
            is_combo = source_id in COMBO_COUNTS and ref['guid'] == COMBO_GUID
            is_static = ref['guid'] in fixed_decor.get(source_id,{})
            if source_id in (10,20) and not is_lake and not is_static and ref['guid'] not in ((upper_guid,detail_guid) if source_id == 10 else (upper_guid,)):
                require(is_combo, '出现未识别的原装饰格')
            allowed = vegetation_sprites[source_id] if is_vegetation else (DIRT_GUID, GRASS_GUID, upper_guid, detail_guid)
            require((is_lake and ref['fileID'] == 11400000 and ref['guid'] in lake_assets)
                    or ((is_static or is_combo) and ref['fileID'] == 11400000)
                    or (ref['guid'] in allowed and (source_id != 0 or ref['guid'] == GRASS_GUID)), '未知地面 Tile')
            if is_lake:
                source_frames = lake_assets[ref['guid']]
                cached = animated[cell]
                require(source_frames == cached['m_AnimatedSprites']
                        and cached['m_AnimationSpeed'] == 1 and cached['m_AnimationTimeOffset'] == cached['m_Flags'] == 0,
                        '湖岸帧序、速率或偏移与场景缓存不一致')
                used_lake_assets.add(ref['guid'])
                # 原 GetTileData 给静态缓存末帧；播放仍从 m_AnimatedSprites 第一帧起。
                sprite = source_frames[-1]
            elif is_combo:
                rule = first_fixed_rule(combo_rule, cell, cells, COMBO_GUID, 1)
                # 原静态作者格不换 Tile；原场景序列化的真实选图比另一个噪声实现更明确。
                sprite = tilemap['m_TileSpriteArray'][data['m_TileSpriteIndex']]['m_Data']
                require(rule is not None and sprite in rule['m_Sprites'], '缓存选图未命中同格原首条邻接规则')
                combo_count += 1
            elif is_static:
                tile, _, is_rule = fixed_decor[source_id][ref['guid']]
                sprite = resolve_fixed_tile_rule(tile, cell, cells, ref['guid']) if is_rule else tile['m_Sprite']
                expected_atlas = CLIFF_SHADOWS_GUID if source_id == 20 and not is_rule else TILES_GUID
                require(sprite['guid'] == expected_atlas, '固定装饰应使用锁定原地面或崖影图集')
                static_counts[ref['guid']] += 1
            elif is_vegetation:
                sprite = vegetation_sprites[source_id][ref['guid']]
                require(sprite['guid'] == tuple(PROPS)[source_id-30], '植被来源图片不符')
            elif ref['guid'] == upper_guid:
                sprite = resolve_fixed_tile_rule(upper, cell, cells, upper_guid)
            elif ref['guid'] == DIRT_GUID:
                sprite = resolve_fixed_tile_rule(dirt, cell, cells, DIRT_GUID)
            else:
                sprite = (detail if ref['guid'] == detail_guid else grass)['m_Sprite']
            require(sprite == tilemap['m_TileSpriteArray'][data['m_TileSpriteIndex']]['m_Data'], '作者规则求值与场景缓存不一致，停止该层')
            matrix = tilemap['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data']
            offsets = [matrix['e03'],matrix['e13']]
            require(matrix == (IDENTITY | {'e03':offsets[0],'e13':offsets[1]}) and (is_vegetation or offsets == [0,0])
                    and all(abs(v) <= 1 and int(v*16) == v*16 for v in offsets)
                    and tilemap['m_TileColorArray'][data['m_TileColorIndex']]['m_Data'] == WHITE
                    and data['m_TileObjectToInstantiateIndex'] == 65535, '不支持的逐格变换/色彩/实例')
            key = f"{sprite['guid']}:{sprite['fileID']}"
            require(key in sprites, '缺少原精灵元数据')
            used.add(key)
            row = {'cell': list(cell), 'sprite':key}
            if is_vegetation: row['translation'] = offsets
            if is_lake:
                keys = [f"{f['guid']}:{f['fileID']}" for f in source_frames]
                require(all(sprites[k]['rect'][2:] == [8,8] and sprites[k]['pivot'] == [.5,.5] for k in keys),
                        '湖岸动画帧尺寸或枢轴变化')
                used.update(keys)
                animated_rows.append({'cell': list(cell),'frames':keys})
            elif is_static or is_combo:
                require(sprites[key]['rect'][2:] == [8,8] and sprites[key]['pivot'] == [.5,.5], '固定装饰尺寸或枢轴变化')
                static_rows.append(row)
            else:
                rows.append(row)
        require(all(indexes[i] == item['m_RefCount'] for i,item in enumerate(tilemap['m_TileSpriteArray'])), '精灵引用数不一致')
        require(source_id != 10 or len(rows) == 158, '来源10可移除草数量不符')
        require(source_id != 20 or len(rows) == 3, '来源20可移除草数量不符')
        layer = {'source_id':source_id,'tilemap_id':tilemap_id,'sorting_order':order,'rows':rows}
        if source_id == 10:
            require(len(animated_rows) == 35 and used_lake_assets == set(lake_assets), '作者湖岸动画缺失')
            layer['decorations'] = {'frames_per_second': 1, 'rows': animated_rows}
        if source_id in fixed_decor:
            require(static_counts == Counter({guid:value[1] for guid,value in fixed_decor[source_id].items()}), '固定装饰格数改变')
            require(combo_count == COMBO_COUNTS[source_id], '作者随机选图装饰格数变化')
            layer['static_decorations'] = static_rows
        layers.append(layer)
    props = {tuple(r['cell']):r['translation'] for r in layers[-2]['rows']}
    shadows = {tuple(r['cell']):r['translation'] for r in layers[-1]['rows']}
    require(props.keys() == shadows.keys() and all(shadows[cell] == [pos[0]-.125,pos[1]] for cell,pos in props.items()),
            '原植被与阴影逐格位移配对变化')
    water_base = extract_water_base(checkout,scene,sprites,used)
    shadows = extract_shadow_layers(checkout,scene,sprites,used,nav)
    pillars = extract_pillars(checkout,scene,sprites,used)
    walls = [extract_wall(checkout,scene,sprites,used,nav,vertical) for vertical in (False,True)]
    cliffs = extract_cliff_bodies(checkout,scene,sprites,used,nav)
    trees = extract_grouped_trees(checkout,scene,sprites,used)
    low_props = extract_low_props(checkout,scene,sprites,used)
    return {'schema':14,'source_commit':SOURCE,'scope':'ground-with-authored-walls-cliffs-and-nature-props',
            'textures':textures,'sprites':{key:sprites[key] for key in sorted(used)},
            'layers':layers,'water_base':water_base,'shadow_layers':shadows,'pillars':pillars,'walls':walls,'cliff_bodies':cliffs,'trees':trees,'low_props':low_props}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unity-checkout',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    try:
        payload = extract(args.unity_checkout)
        write_local(args.output,payload)
    except (ValueError, KeyError, TypeError, OSError, yaml.YAMLError, subprocess.CalledProcessError) as error:
        parser.exit(2,f'原地面抽取拒绝执行：{error}\n')
    print('基础地面900格、Grass覆盖547格、来源10/20映射草158/3格、来源30/31植被及阴影各33格、LakeGrass动画35格、来源10固定装饰15格、来源20固定装饰4格；原河湖底图87格；原场景缓存石草混合装饰59/6格；原地表阴影35格、墙体阴影7格、14根原柱子及独立柱影、原横墙56格、纵墙11格、崖体三层151格、13 棵原分组树、19 株藤蔓和 13 株香蒲。不重算 Unity Perlin，不抽取倒影。')

if __name__ == '__main__': main()
