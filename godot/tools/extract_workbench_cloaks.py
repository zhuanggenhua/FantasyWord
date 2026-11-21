"""生成私有的原披风/人类躯干变体验证合同，不复制贴图。"""
import argparse, hashlib, json
from pathlib import Path
from extract_formal_human_animation import SOURCE, read, parse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("repo", type=Path, help="含锁定提交的 Unity Git 仓库")
parser.add_argument("directory", type=Path, help="含已获授权的十张原披风 PNG 的私有目录")
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
for key in ('Idle','Walk','Attack','Dmg'):
    guid=parse(read(repo,R+f'AnimationType/{key}.asset.meta'))['guid']
    matching=[r for r in records if guid in r.splitlines()[0]]
    assert len(matching)==1, key
    record=matching[0]
    use=[line[2:] for line in record.splitlines()[1:] if line.startswith(selected)]
    parsed=parse(('- animationType: '+record.splitlines()[0]+'\n'+'\n'.join(use)).encode())[0]
    result=[]
    for row in parsed['frames']:
        torso=next((r for r in row['bodyRegions'] if r['part']==1),None)
        result.append([row['frameIndex'],row['rowIndex'],torso['spriteFacing'] if torso else row['rowIndex'],torso['variant'] if torso else 0])
    frames[key]=result
assert len(frames['Dmg'])==16 and sum(r[3]==3 for r in frames['Dmg'])==8
assert [0,0,0,3] in frames['Dmg']
assert all(r[3]==0 and r[1]==r[2] for key,rows in frames.items() if key!='Dmg' for r in rows)
(base/'cloak.json').write_text(json.dumps({'source_commit':SOURCE,'source_sha256':sources,'options':slots,'textures':tex,'frames':frames},indent=2,ensure_ascii=False)+'\n', encoding='utf-8')
