"""生成私有的原披风/人类躯干变体验证合同，不复制贴图。"""
import argparse, hashlib, json
from pathlib import Path
from extract_formal_human_animation import CRAFT, GATHER, SOURCE, read, parse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("repo", type=Path, help="含锁定提交的 Unity Git 仓库")
parser.add_argument("directory", type=Path, help="含已获授权的十张原披风 PNG 的私有目录")
parser.add_argument("--include-slash-attack", action="store_true", help="同时验证挥砍躯干的 16 个原帧")
parser.add_argument("--workbench-spin", action="store_true", help="同时验证旋转死亡的共用躯干行号")
parser.add_argument("--include-charged", action="store_true", help="验证蓄力的三行躯干帧与空武器挂点")
parser.add_argument("--workbench-moves", action="store_true", help="核实 Dmg2、Jump 和 SoulDie 原躯干与空手锚")
parser.add_argument("--workbench-gather", action="store_true", help="核实三个原采集动作躯干及空手锚")
parser.add_argument("--workbench-craft", action="store_true", help="核实四个制作台动作的共用原躯干行及挂点")
args = parser.parse_args()
base, repo = args.directory, args.repo
R = 'Assets/GameData/EquipmentSystem/'
A = 'Assets/ThirdParty/MiniFantasyUV/ImportedSource/Art/equip/'
direction = ('SE', 'SW', 'NE', 'NW')
def body(path):
    return parse(read(repo, path))['MonoBehaviour']

sources = {}
tex = {}
for name in [f'clock{i}.png' for i in range(1, 9)] + ['斗篷.png', '斗篷1.png']:
    raw = (base / name).read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    pointer = read(repo, A + name).decode()
    importer = parse(read(repo, A + name + '.meta'))
    assert f'oid sha256:{sha}' in pointer.splitlines() and f'size {len(raw)}' in pointer.splitlines(), name
    assert importer['TextureImporter']['textureSettings']['filterMode'] == 0
    tex[importer['guid']] = {'file': name, 'sha256': sha}
assert len(tex)==10
def ref(record):
    if record['fileID']==0: return None
    assert record['fileID']==21300000 and record['guid'] in tex
    return record['guid']
catalog_path = R+'Data/Workbench/换装工作台目录.asset'
catalog = body(catalog_path)
sources[catalog_path] = hashlib.sha256(read(repo,catalog_path)).hexdigest()
slots = []
for name in ['旅行披风','厚斗篷']:
    path=R+'Equip/Visual/'+name+'.asset'
    sources[path]=hashlib.sha256(read(repo,path)).hexdigest()
    data=body(path)
    guid=parse(read(repo,path+'.meta'))['guid']
    assert data['equipmentId']==1 and data['type']==3 and not data['animSequences']
    option=next(o for o in catalog['equipments'] if o['visual']['guid']==guid)
    sprites = [[ref(data['sprite'+d]) for d in direction]]
    sprites.extend([ref(data[v+'Variant'][d.lower()]) for d in direction] for v in ('up','down','left','right'))
    slots.append({'guid':guid,'name':option['displayName'],'description':option['description'],'stats':option['bonusStats']['values'],'sprite_sets':sprites})
assert slots[0]['guid']!=slots[1]['guid']
assert [tex[g]['file'] for g in slots[0]['sprite_sets'][0]]==[f'clock{i}.png' for i in range(1,5)]
assert [tex[g]['file'] if g else None for g in slots[1]['sprite_sets'][0]]==['斗篷.png','斗篷1.png',None,None]
assert [tex[g]['file'] for g in slots[1]['sprite_sets'][3]]==[f'clock{i}.png' for i in range(5,9)]
assert slots[1]['sprite_sets'][4][0] is None and slots[1]['sprite_sets'][4][1:]==slots[1]['sprite_sets'][3][1:]
frames = {}
frame_path=R+'FrameData/人类帧数据.asset'
raw=read(repo,frame_path)
sources[frame_path]=hashlib.sha256(raw).hexdigest()
records=raw.decode().split('\n  - animationType: ')[1:]
selected=('    frames:', '    - frameIndex:', '      rowIndex:', '      bodyRegions:', '      - part:', '        spriteFacing:', '        variant:')
anchor_fields=('      anchors:', '      - type:', '        position:', '        direction:')
for key in ('Idle','Walk','Attack','Dmg') + (('SlashAttack',) if args.include_slash_attack else ()) + (('SpinDie',) if args.workbench_spin else ()) + (('ChargedAttack',) if args.include_charged else ()) + (('Dmg2','Jump','SoulDie') if args.workbench_moves else ()) + (GATHER if args.workbench_gather else ()) + (tuple(CRAFT) if args.workbench_craft else ()):
    guid=parse(read(repo,R+f'AnimationType/{key}.asset.meta'))['guid']
    matching=[r for r in records if guid in r.splitlines()[0]]
    assert len(matching)==1, key
    record=matching[0]
    use=[line[2:] for line in record.splitlines()[1:] if line.startswith(selected + (anchor_fields if key in ('SpinDie','ChargedAttack','Dmg2','Jump','SoulDie') + GATHER + tuple(CRAFT) else ()))]
    parsed=parse(('- animationType: '+record.splitlines()[0]+'\n'+'\n'.join(use)).encode())[0]
    result=[]
    for row in parsed['frames']:
        if key == 'SpinDie':
            if row['rowIndex'] != 0: continue
            assert row['anchors'] == [], '原旋转死亡不可预览带挂点武器'
        torso=next((r for r in row['bodyRegions'] if r['part']==1),None)
        if key in ('ChargedAttack','Dmg2','Jump','SoulDie') + GATHER + tuple(CRAFT):
            assert row['anchors'] == []
        if key in ('SlashAttack','ChargedAttack','Dmg2','Jump','SoulDie') + GATHER + tuple(CRAFT):
            assert torso is not None, (key, row['frameIndex'], row['rowIndex'])
        result.append([row['frameIndex'],row['rowIndex'],torso['spriteFacing'] if torso else row['rowIndex'],torso['variant'] if torso else 0])
    frames[key]=result
if args.include_slash_attack:
    assert sorted(frames['SlashAttack']) == [[label, facing, facing, 0] for label in range(4) for facing in range(4)]
if args.workbench_spin:
    assert frames['SpinDie'] == [[label, 0, 0, 0] for label in range(12)]
    spin = parse(read(repo,R+'AnimationType/SpinDie.asset.meta'))['guid']
    for name in ('长矛','战斧','重盾','圆盾'):
        assert spin not in read(repo,R+f'Equip/Visual/{name}.asset').decode(), name
if args.include_charged:
    assert frames['ChargedAttack'] == [[label,row,row,0] for row in range(3) for label in range(6)]
    charged = parse(read(repo,R+'AnimationType/ChargedAttack.asset.meta'))['guid']
    for name in ('长矛','战斧','重盾','圆盾'):
        assert charged not in read(repo,R+f'Equip/Visual/{name}.asset').decode(), name
if args.workbench_moves:
    for action in ('Dmg2','Jump','SoulDie'):
        row_count, samples = (1,12) if action=='SoulDie' else (4,4)
        assert frames[action] == [[label,row,row,0] for row in range(row_count) for label in range(samples)]
        guid = parse(read(repo,R+f'AnimationType/{action}.asset.meta'))['guid']
        for name in ('长矛','战斧','重盾','圆盾'):
            assert guid not in read(repo,R+f'Equip/Visual/{name}.asset').decode(), name
if args.workbench_gather:
    for action in GATHER:
        assert frames[action] == [[label,row,row,0] for row in range(4) for label in range(6)]
        guid = parse(read(repo,R+f'AnimationType/{action}.asset.meta'))['guid']
        for name in ('长矛','战斧','重盾','圆盾'):
            assert guid not in read(repo,R+f'Equip/Visual/{name}.asset').decode(), name
if args.workbench_craft:
    for action, count in CRAFT.items():
        assert frames[action] == [[label,0,0,0] for label in range(count)]
        guid = parse(read(repo,R+f'AnimationType/{action}.asset.meta'))['guid']
        for name in ('长矛','战斧','重盾','圆盾'):
            assert guid not in read(repo,R+f'Equip/Visual/{name}.asset').decode(), name
assert len(frames['Dmg'])==16 and sum(r[3]==3 for r in frames['Dmg'])==8
assert [0,0,0,3] in frames['Dmg']
assert all(r[3]==0 and r[1]==r[2] for key,rows in frames.items() if key!='Dmg' for r in rows)
(base/'cloak.json').write_text(json.dumps({'source_commit':SOURCE,'source_sha256':sources,'options':slots,'textures':tex,'frames':frames},indent=2,ensure_ascii=False)+'\n', encoding='utf-8')
