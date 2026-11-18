#!/usr/bin/env python3
"""抽取锁定场景的真实基础地面与 Grass 覆盖层，输出只能在仓库外。

Dirt 按作者 RuleTile 的 Fixed/Single 首个匹配规则求值，再逐格核对场景缓存。
依据锁定 packages-lock 的 Unity 2D Tilemap Extras 6.0.1 RuleTile.cs。
仅负责两层的静态图像布局，不复制图片，也不把其他四个覆盖来源当作已迁移。
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


def resolve_dirt(rule_asset, cell, authored_cells):
    """仅实现这份作者配置实际使用的 Fixed/Single；不猜随机或旋转规则。"""
    sprite = rule_asset['m_DefaultSprite']
    for rule in rule_asset['m_TilingRules']:
        require(rule['m_RuleTransform'] == 0 and rule['m_Output'] == 0, '不是固定单图规则')
        raw = bytes.fromhex(rule['m_Neighbors'])
        require(len(raw) % 4 == 0, '邻接字节损坏')
        neighbors = struct.unpack('<' + 'i' * (len(raw) // 4), raw)
        positions = rule['m_NeighborPositions']
        matched = True
        for neighbor, offset in zip(neighbors, positions):
            other = authored_cells.get(tuple(a+b for a,b in zip(cell, xyz(offset))), {})
            same = other.get('guid') == DIRT_GUID
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
    layers, used = [], set()
    for tilemap_id, renderer_id, source_id, order, count in ((875022404,875022403,-1,-10,900),(1835126662,1835126661,0,-9,547)):
        cells = tile_cells(scene, tilemap_id)
        tilemap = get_document(scene, tilemap_id, 'Tilemap')
        renderer = get_document(scene, renderer_id, 'TilemapRenderer')
        require(len(cells) == count and not tilemap['m_AnimatedTiles'] and tilemap['m_Color'] == WHITE
                and tilemap['m_TileOrientationMatrix'] == IDENTITY and tilemap['m_TileOrientation'] == 0
                and renderer['m_Enabled'] == 1 and renderer['m_SortingLayerID'] == 0
                and renderer['m_SortingOrder'] == order and renderer['m_Mode'] == 0
                and renderer['m_Materials'] == [{'fileID':10754,'guid':'0000000000000000f000000000000000','type':0}],
                '不是锁定的静态原生材质地面层')
        rows, indexes = [], Counter()
        for entry in tilemap['m_Tiles']:
            cell, data = tuple(xyz(entry['first'])), entry['second']
            ref = cells[cell]
            require(ref['guid'] in (DIRT_GUID, GRASS_GUID) and (source_id != 0 or ref['guid'] == GRASS_GUID), '未知地面 Tile')
            sprite = resolve_dirt(dirt, cell, cells) if ref['guid'] == DIRT_GUID else grass['m_Sprite']
            require(sprite == tilemap['m_TileSpriteArray'][data['m_TileSpriteIndex']]['m_Data'], '作者规则求值与场景缓存不一致，停止该层')
            require(tilemap['m_TileMatrixArray'][data['m_TileMatrixIndex']]['m_Data'] == IDENTITY
                    and tilemap['m_TileColorArray'][data['m_TileColorIndex']]['m_Data'] == WHITE
                    and data['m_TileObjectToInstantiateIndex'] == 65535, '不支持的逐格变换/色彩/实例')
            key = f"{sprite['guid']}:{sprite['fileID']}"
            require(key in sprites, '缺少原精灵元数据')
            used.add(key)
            indexes[data['m_TileSpriteIndex']] += 1
            rows.append({'cell': list(cell), 'sprite':key})
        require(all(indexes[i] == item['m_RefCount'] for i,item in enumerate(tilemap['m_TileSpriteArray'])), '精灵引用数不一致')
        layers.append({'source_id':source_id,'tilemap_id':tilemap_id,'sorting_order':order,'rows':rows})
    return {'schema':1,'source_commit':SOURCE,'scope':'base-and-grass-cover',
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
    print('原基础地面 900 格与 Grass 覆盖 547 格，Dirt 617 格规则求值与原缓存逐格一致。')

if __name__ == '__main__': main()
