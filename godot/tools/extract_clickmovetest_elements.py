#!/usr/bin/env python3
"""从锁定 Unity 对象抽取 ClickMoveTest 覆盖与三条草地火水反应。

仅输出本机私有数值夹具，不复制原始场景、素材或图片；输出不得位于 Git 仓库。
这不是全部元素系统或视觉迁移。依赖 PyYAML 和同目录规则抽取器。
"""
import argparse
from collections import Counter
from pathlib import Path
import re
import subprocess

import yaml
from extract_clickmovetest_rules import (
    SOURCE, SCENE, RULE_TILEMAP, git, get_document, require, xyz,
    expect_rectangular_grid, write_local,
)

# 来源 ID、职责、Tilemap 文档、优先级以及精确映射合同。
LAYERS = (
    (0, 2, 1835126662, 0, [('ee44f04c19e463d48a8796f568a766fa', 1, 7)]),
    (10, 3, 453769794, 10, [('e41387fb62d13cf40aa1d24ec147cee0', 1, 3), ('e3e7c5e9438735847b05de88b6910a83', 1, 3)]),
    (20, 3, 913349356, 20, [('e41387fb62d13cf40aa1d24ec147cee0', 1, 3)]),
    (30, 3, 897197880, 30, [('07f6cb5b96834d24a9f819f03c59b117', 5, 3), ('fec71c5cda67e6845a30b1b5147ea2c0', 5, 3), ('2c7567f0516386d4794e9ad921eb4666', 5, 3), ('db57237f70e2f5d49a565eb058f4da2d', 1, 3), ('09a236e14f449dd44a2b39434ab3e8a0', 1, 3)]),
    (31, 6, 994996502, 31, [('6eab1cea3fa254e4eb0d776e44b7c208', 5, 3), ('9d28869eda0ce274e8043d03404f0452', 5, 3), ('59799c774c985254b9eed8a4910e1f02', 5, 3), ('4d6a07e2fb9f83f49b55b940c4d73854', 1, 3), ('68d2734a9d12a954aa191591530b240f', 1, 3)]),
)
STATE_FIELDS = ('m_stateKind', 'm_defaultDuration', 'm_mergePolicy', 'm_traversalCostMultiplier')
REACTION_FIELDS = ('m_trigger', 'm_elementKind', 'm_expiredStateKind', 'm_minimumIntensity',
                   'm_requireBaseSurface', 'm_baseSurface', 'm_requireEffectiveSurface',
                   'm_effectiveSurface', 'm_requireSurfaceCover', 'm_surfaceCover',
                   'm_requiredSurfaceCoverTraits', 'm_forbiddenSurfaceCoverTraits',
                   'm_requiredStates', 'm_forbiddenStates', 'm_priority')
OP_FIELDS = ('m_kind', 'm_stateKind', 'm_intensityMultiplier', 'm_durationOverride',
             'm_surfaceKind', 'm_surfaceCoverKind', 'm_presentationSignal')


def read(checkout, path):
    return git(checkout, 'show', f'{SOURCE}:{path}')


def tile_cells(scene, tilemap_id):
    tilemap = get_document(scene, tilemap_id, 'Tilemap')
    require(xyz(tilemap['m_TileAnchor']) == [.5, .5, 0], '覆盖层锚点不一致')
    go = get_document(scene, tilemap['m_GameObject']['fileID'], 'GameObject')
    transform = get_document(scene, go['m_Component'][0]['component']['fileID'], 'Transform')
    require(transform['m_Father']['fileID'] == 1148507050
            and xyz(transform['m_LocalPosition']) == [0, 0, 0]
            and xyz(transform['m_LocalScale']) == [1, 1, 1]
            and xyz(transform['m_LocalRotation']) == [0, 0, 0]
            and abs(transform['m_LocalRotation']['w']) == 1, '覆盖层未对齐锁定 Grid')
    refs = tilemap['m_TileAssetArray']
    counts, cells = Counter(), {}
    origin, size = xyz(tilemap['m_Origin']), xyz(tilemap['m_Size'])
    for tile in tilemap['m_Tiles']:
        cell, index = tuple(xyz(tile['first'])), tile['second']['m_TileIndex']
        require(cell[2] == 0 and cell not in cells and 0 <= index < len(refs)
                and all(o <= c < o + n for o, c, n in zip(origin, cell, size)), '非法覆盖格或索引')
        cells[cell] = refs[index]['m_Data']
        counts[index] += 1
    require(all(counts[i] == entry['m_RefCount'] for i, entry in enumerate(refs)), '覆盖 Tile 引用计数不一致')
    return cells


def database_entry(checkout, path, classname, script_guid, registry):
    asset = get_document(read(checkout, path), 11400000, 'MonoBehaviour')
    require(asset['m_EditorClassIdentifier'] == 'FantasyWord.GameCore::FantasyWord.GameCore.' + classname
            and asset['m_Script']['guid'] == script_guid and asset['m_Enabled'] == 1,
            '元素配置身份不一致')
    meta = yaml.safe_load(read(checkout, path + '.meta'))
    matches = [key for key, ref in zip(registry['m_keys'], registry['m_values'])
               if ref.get('guid') == meta['guid'] and ref['fileID'] == 11400000]
    require(len(matches) == 1 and re.fullmatch('[0-9a-f]{32}', matches[0]), '数据库稳定 ID 不唯一')
    return asset, matches[0]


def extract(checkout):
    require(git(checkout, 'rev-parse', SOURCE).strip() == SOURCE, '锁定源提交不存在')
    scene = read(checkout, SCENE)
    expect_rectangular_grid(scene)
    nav = get_document(scene, 1148507052, 'MonoBehaviour')
    require(nav['m_EditorClassIdentifier'].endswith('.TerrainNavigationMap')
            and nav['m_Script']['guid'] == '6a04619aaf8e4d349a6aba427a4507f3', '导航配置身份不一致')
    sources = nav['m_surfaceLayerSources']
    require(len(sources) == len(LAYERS) and nav['m_surfaceCoverTilemap']['fileID'] == 0
            and not nav['m_surfaceCoverTileMappings'], '不是锁定的五来源配置')
    rule_cells = {tuple(xyz(tile['first'])) for tile in get_document(scene, RULE_TILEMAP, 'Tilemap')['m_Tiles']}
    covers = {}
    # 原实现 priority 升序，第一次成功解析即返回；不得让后层覆盖前层。
    for source, (sid, role, tilemap, priority, mappings) in zip(sources, LAYERS):
        require((source['m_sourceId'], source['m_role'], source['m_tilemap']['fileID'], source['m_priority'])
                == (sid, role, tilemap, priority), '覆盖来源身份或优先级不一致')
        actual = source['m_surfaceCoverTileMappings']
        require([(m['m_tile']['guid'], m['m_coverKind'], m['m_traits']) for m in actual] == mappings
                and all(m['m_tile']['fileID'] == 11400000 and m['m_tile']['type'] == 2 for m in actual),
                '覆盖映射合同不一致')
        mapped = {guid: (kind, traits) for guid, kind, traits in mappings}
        for cell, ref in tile_cells(scene, tilemap).items():
            if cell not in rule_cells or cell in covers or ref.get('guid') not in mapped:
                continue
            require(ref['fileID'] == 11400000 and ref['type'] == 2, '覆盖 Tile 对象身份不一致')
            kind, traits = mapped[ref['guid']]
            covers[cell] = {'cell': list(cell), 'kind': kind, 'traits': traits, 'source_id': sid}
    system = get_document(scene, 204002010, 'MonoBehaviour')
    require(system['m_EditorClassIdentifier'].endswith('.ElementReactionSystem')
            and system['m_Script']['guid'] == '3a67857035058504e88c105b48205e95'
            and system['m_Enabled'] == 1 and system['m_fixedStepSeconds'] == .1,
            '元素系统身份或步长不一致')
    registry = get_document(read(checkout, 'Assets/GameData/GameCore/DatabaseRegistry.asset'),
                            11400000, 'MonoBehaviour')['m_entries']
    require(len(registry['m_keys']) == len(registry['m_values'])
            and len(set(registry['m_keys'])) == len(registry['m_keys']), '数据库键值不一致')
    states, reactions = [], []
    for name in ('燃烧', '湿润'):
        asset, stable_id = database_entry(checkout, f'Assets/GameData/Elements/States/地表元素状态-{name}.asset',
                                         'TerrainElementStateDefinition', 'bf0f7aabb9fb01b4c959045bdc10249e', registry)
        states.append({'stable_id': stable_id, **{key: asset[key] for key in STATE_FIELDS}})
    for name in ('火焰点燃草地', '草地燃尽形成焦土', '水熄灭燃烧'):
        asset, stable_id = database_entry(checkout, f'Assets/GameData/Elements/Reactions/元素反应-{name}.asset',
                                         'ElementReactionDefinition', '7640e02495c74f84c8280ac6933f1aee', registry)
        # 水资产未序列化后加的覆盖字段；原 C# 初始化值均为 None/false（0）。
        defaulted = {'m_requireSurfaceCover', 'm_surfaceCover', 'm_requiredSurfaceCoverTraits', 'm_forbiddenSurfaceCoverTraits'}
        row = {'stable_id': stable_id}
        for key in REACTION_FIELDS:
            require(key in asset or key in defaulted, '缺失必需反应字段')
            row[key] = asset.get(key, 0)
        row['m_operations'] = []
        for operation in asset['m_operations']:
            require(all(key in operation or key == 'm_surfaceCoverKind' for key in OP_FIELDS), '缺失必需操作字段')
            row['m_operations'].append({key: operation.get(key, 0) for key in OP_FIELDS})
        reactions.append(row)
    return {'schema': 1, 'source_commit': SOURCE, 'fixed_step': system['m_fixedStepSeconds'],
            'cover_rows': sorted(covers.values(), key=lambda row: (row['cell'][1], row['cell'][0])),
            'states': states, 'reactions': reactions}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unity-checkout', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        payload = extract(args.unity_checkout)
        write_local(args.output, payload)
    except (ValueError, OSError, KeyError, TypeError, yaml.YAMLError, subprocess.CalledProcessError) as exc:
        parser.exit(2, f'ClickMoveTest 元素抽取拒绝执行：{exc}\n')
    print(f"覆盖格 {len(payload['cover_rows'])}，状态 {len(payload['states'])}，反应 {len(payload['reactions'])}")


if __name__ == '__main__':
    main()
