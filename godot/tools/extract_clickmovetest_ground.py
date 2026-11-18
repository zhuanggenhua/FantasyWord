#!/usr/bin/env python3
"""抽取锁定场景的真实基础地面与 Grass 覆盖层，输出只能在仓库外。

Dirt 按作者 RuleTile 的 Fixed/Single 首个匹配规则求值，再逐格核对场景缓存。
依据锁定 packages-lock 的 Unity 2D Tilemap Extras 6.0.1 RuleTile.cs。
负责基础地面、映射覆盖和已经求值的来源10装饰，不复制图片。
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
SOURCE10_STATIC = {
    'Standard Tiles/Ground/Dirt8_Minifantasy_ForgottenPlainsTiles_74':1,
    'Standard Tiles/Ground/Dirt19_Minifantasy_ForgottenPlainsTiles_4':7,
    'Standard Tiles/Ground/Dirt5_Minifantasy_ForgottenPlainsTiles_46':1,
    'Standard Tiles/Ground/Dirt2_Minifantasy_ForgottenPlainsTiles_21':1,
    'Standard Tiles/Cliffs/Cliff34_Minifantasy_ForgottenPlainsTiles_510':1,
    'Rule Tiles/CobblestoneGrass 3':4,
}
PROPS = {'be785b53e8101134cb49e391918a7a82': 'Props.png',
         'da4d732596845594e9b99bf9488ee15f': 'PropsShadow.png'}
DEFAULT_TILE_MATERIAL = [{'fileID':10754,'guid':'0000000000000000f000000000000000','type':0}]
SPRITE_LIT_MATERIAL = [{'fileID':2100000,'guid':'a97c105638bdf8b4a8650670310a4cd3','type':2}]
IDENTITY = {f'e{y}{x}': int(x == y) for y in range(4) for x in range(4)}
WHITE = dict(r=1, g=1, b=1, a=1)


def read(checkout, path):
    return git(checkout, 'show', f'{SOURCE}:{path}')


def resolve_fixed_tile_rule(rule_asset, cell, authored_cells, tile_guid):
    """仅实现这份作者配置实际使用的 Fixed/Single；不猜随机或旋转规则。"""
    sprite = rule_asset['m_DefaultSprite']
    for rule in rule_asset['m_TilingRules']:
        require(rule['m_RuleTransform'] == 0 and rule['m_Output'] == 0, '不是固定单图规则')
        raw = bytes.fromhex(rule['m_Neighbors'] or '')
        require(len(raw) % 4 == 0, '邻接字节损坏')
        neighbors = struct.unpack('<' + 'i' * (len(raw) // 4), raw)
        positions = rule['m_NeighborPositions'] or []
        # 原 RuleMatches 使用两数组长度的最小值；Grass末规则保留8位置但无邻接。
        require(all(n in (0,1,2) for n in neighbors), '邻接类型不支持')
        matched = True
        for neighbor, offset in zip(neighbors, positions):
            other = authored_cells.get(tuple(a+b for a,b in zip(cell, xyz(offset))), {})
            same = other.get('guid') == tile_guid
            if (neighbor == 1 and not same) or (neighbor == 2 and same):
                matched = False
                break
        if matched:
            return rule['m_Sprites'][0]
    return sprite


def source10_static_tiles(checkout):
    tiles = {}
    for name, count in SOURCE10_STATIC.items():
        path = ROOT + 'Tile Palettes/' + name + '.asset'
        guid = yaml.safe_load(read(checkout, path + '.meta'))['guid']
        raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout, path))
        tile = get_document(raw, 11400000, 'MonoBehaviour')
        require(guid not in tiles and tile['m_Name'] == name.split('/')[-1], '来源10装饰作者资产不符')
        rule_tile = name.startswith('Rule Tiles/')
        if rule_tile:
            require(tile['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231'
                    and tile['m_DefaultGameObject']['fileID'] == 0
                    and all(r['m_RuleTransform'] == r['m_Output'] == r['m_RandomTransform'] == 0
                            and r['m_GameObject']['fileID'] == 0 for r in tile['m_TilingRules']),
                    '原石路不是固定单图规则')
        else:
            require(tile['m_Script'] == {'fileID':13312,'guid':'0000000000000000e000000000000000','type':0}
                    and tile['m_Transform'] == IDENTITY and tile['m_Color'] == WHITE
                    and tile['m_InstancedGameObject']['fileID'] == 0, '不是原普通静态 Tile')
        tiles[guid] = (tile, count, rule_tile)
    return tiles


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
    for guid, filename in (TEXTURES | PROPS).items():
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
    fixed_decor = source10_static_tiles(checkout)
    require(not set(fixed_decor).intersection(m['m_tile']['guid'] for m in source10['m_surfaceCoverTileMappings']),
            '固定装饰不应属于作者映射草')
    layer10 = get_document(scene,453769791,'GameObject')
    require(layer10['m_IsActive'] == 1 and [c['component']['fileID'] for c in layer10['m_Component']]
            == [453769792,453769794,453769793], '来源10装饰层不应带有物理组件')
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
        if source_id in (10,30,31):
            node_id = {10:453769792,30:897197882,31:994996504}[source_id]
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
        for entry in tilemap['m_Tiles']:
            cell, data = tuple(xyz(entry['first'])), entry['second']
            ref = cells[cell]
            indexes[data['m_TileSpriteIndex']] += 1
            is_lake = source_id == 10 and cell in animated
            is_static = source_id == 10 and ref['guid'] in fixed_decor
            if source_id in (10,20) and not is_lake and not is_static and ref['guid'] not in ((upper_guid,detail_guid) if source_id == 10 else (upper_guid,)):
                # 保留全层引用核对，但未求值的随机/旁观瓦片不冒充完成。
                continue
            allowed = vegetation_sprites[source_id] if is_vegetation else (DIRT_GUID, GRASS_GUID, upper_guid, detail_guid)
            require((is_lake and ref['fileID'] == 11400000 and ref['guid'] in lake_assets)
                    or (is_static and ref['fileID'] == 11400000)
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
            elif is_static:
                tile, _, is_rule = fixed_decor[ref['guid']]
                sprite = resolve_fixed_tile_rule(tile, cell, cells, ref['guid']) if is_rule else tile['m_Sprite']
                require(sprite['guid'] == TILES_GUID, '固定装饰应使用锁定原地面图集')
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
            elif is_static:
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
            require(static_counts == Counter({guid:value[1] for guid,value in fixed_decor.items()}), '固定装饰格数改变')
            layer['static_decorations'] = static_rows
        layers.append(layer)
    props = {tuple(r['cell']):r['translation'] for r in layers[-2]['rows']}
    shadows = {tuple(r['cell']):r['translation'] for r in layers[-1]['rows']}
    require(props.keys() == shadows.keys() and all(shadows[cell] == [pos[0]-.125,pos[1]] for cell,pos in props.items()),
            '原植被与阴影逐格位移配对变化')
    return {'schema':4,'source_commit':SOURCE,'scope':'base-mapped-covers-and-source10-animations-fixed-decor',
            'textures':textures,'sprites':{key:sprites[key] for key in sorted(used)},'layers':layers}


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
    print('基础地面900格、Grass覆盖547格、来源10/20映射草158/3格、来源30/31植被及阴影各33格、LakeGrass动画35格、来源10固定装饰15格；随机装饰59/6格和来源20其余4格未装配。')

if __name__ == '__main__': main()
