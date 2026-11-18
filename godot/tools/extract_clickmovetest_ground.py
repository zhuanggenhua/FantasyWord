#!/usr/bin/env python3
"""抽取锁定场景的真实基础地面与 Grass 覆盖层，输出只能在仓库外。

Dirt 按作者 RuleTile 的 Fixed/Single 首个匹配规则求值，再逐格核对场景缓存。
依据锁定 packages-lock 的 Unity 2D Tilemap Extras 6.0.1 RuleTile.cs。
仅负责基础两层与来源10/20的161格可移除草，不复制图片；其余层和旁观瓦片未装配。
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


def extract(checkout):
    scene = read(checkout, SCENE)
    expect_rectangular_grid(scene)
    dirt_raw = re.sub(r'(m_Neighbors: )([0-9a-f]+)', r'\1"\2"', read(checkout, DIRT))
    dirt = get_document(dirt_raw, 11400000, 'MonoBehaviour')
    grass = get_document(read(checkout, GRASS), 11400000, 'MonoBehaviour')
    require(dirt['m_Script']['guid'] == '9d1514134bc4fbd41bb739b1b9a49231'
            and len(dirt['m_TilingRules']) == 15 and grass['m_Transform'] == IDENTITY
            and grass['m_Color'] == WHITE, '地面作者资产不匹配')
    textures, sprites = {}, {}
    for guid, filename in TEXTURES.items():
        path = ROOT + 'Sprites/Tileset/' + filename
        metadata = yaml.safe_load(read(checkout, path + '.meta'))
        importer = metadata['TextureImporter']
        require(metadata['guid'] == guid and importer['spritePixelsToUnits'] == 8
                and importer['spriteMode'] == 2 and importer['spriteMeshType'] == 1
                and importer['mipmaps']['sRGBTexture'] == 1 and importer['mipmaps']['enableMipMap'] == 0
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
    layers, used = [], set()
    for tilemap_id, renderer_id, source_id, order, count in ((875022404,875022403,-1,-10,900),(1835126662,1835126661,0,-9,547),(453769794,453769793,10,-8,267),(913349356,913349355,20,-1,13)):
        cells = tile_cells(scene, tilemap_id)
        tilemap = get_document(scene, tilemap_id, 'Tilemap')
        renderer = get_document(scene, renderer_id, 'TilemapRenderer')
        require(len(cells) == count and (source_id == 10 or not tilemap['m_AnimatedTiles']) and tilemap['m_Color'] == WHITE
                and tilemap['m_TileOrientationMatrix'] == IDENTITY and tilemap['m_TileOrientation'] == 0
                and renderer['m_Enabled'] == 1 and renderer['m_SortingLayerID'] == 0
                and renderer['m_SortingOrder'] == order and renderer['m_Mode'] == 0
                and renderer['m_Materials'] == [{'fileID':10754,'guid':'0000000000000000f000000000000000','type':0}],
                '不是锁定的静态原生材质地面层')
        rows, indexes = [], Counter()
        for entry in tilemap['m_Tiles']:
            cell, data = tuple(xyz(entry['first'])), entry['second']
            ref = cells[cell]
            indexes[data['m_TileSpriteIndex']] += 1
            if source_id in (10,20) and ref['guid'] not in ((upper_guid,detail_guid) if source_id == 10 else (upper_guid,)):
                # 保留全层引用核对，但未求值的随机/旁观瓦片不冒充完成。
                continue
            require(ref['guid'] in (DIRT_GUID, GRASS_GUID, upper_guid, detail_guid) and (source_id != 0 or ref['guid'] == GRASS_GUID), '未知地面 Tile')
            require(not any(tuple(xyz(a['first'])) == cell for a in tilemap['m_AnimatedTiles']), '映射覆盖格含动画，不能静态装配')
            if ref['guid'] == upper_guid:
                sprite = resolve_fixed_tile_rule(upper, cell, cells, upper_guid)
            elif ref['guid'] == DIRT_GUID:
                sprite = resolve_fixed_tile_rule(dirt, cell, cells, DIRT_GUID)
            else:
                sprite = (detail if ref['guid'] == detail_guid else grass)['m_Sprite']
            require(sprite == tilemap['m_TileSpriteArray'][data['m_TileSpriteIndex']]['m_Data'], '作者规则求值与场景缓存不一致，停止该层')
            require(tilemap['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data'] == IDENTITY
                    and tilemap['m_TileColorArray'][data['m_TileColorIndex']]['m_Data'] == WHITE
                    and data['m_TileObjectToInstantiateIndex'] == 65535, '不支持的逐格变换/色彩/实例')
            key = f"{sprite['guid']}:{sprite['fileID']}"
            require(key in sprites, '缺少原精灵元数据')
            used.add(key)
            rows.append({'cell': list(cell), 'sprite':key})
        require(all(indexes[i] == item['m_RefCount'] for i,item in enumerate(tilemap['m_TileSpriteArray'])), '精灵引用数不一致')
        require(source_id != 10 or len(rows) == 158, '来源10可移除草数量不符')
        require(source_id != 20 or len(rows) == 3, '来源20可移除草数量不符')
        layers.append({'source_id':source_id,'tilemap_id':tilemap_id,'sorting_order':order,'rows':rows})
    return {'schema':1,'source_commit':SOURCE,'scope':'base-grass-and-mapped-covers-10-20',
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
    print('原基础地面900格、Grass覆盖547格、来源10/20可移除草158/3格；旁观瓦片109/10格未装配。')

if __name__ == '__main__': main()
