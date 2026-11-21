#!/usr/bin/env python3
"""核对战马原素材并生成无装备骑手私有帧合同。"""
import argparse
import concurrent.futures
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path
from extract_formal_human_animation import SOURCE, parse, read

cli = argparse.ArgumentParser(description=__doc__)
cli.add_argument("repo", type=Path)
cli.add_argument("private_directory", type=Path)
args = cli.parse_args()
R, D = args.repo, args.private_directory
PATH='Assets/GameData/EquipmentSystem/Mounts/战马_人类骑乘表现.asset'
paths=subprocess.check_output(['git','-c','core.quotepath=false','-C',str(R),'ls-tree','-r','--name-only',SOURCE],text=True).splitlines()
files={
 'mount_stand':'待机_stallion.png','mount_move':'行走_stallion.png',
 'rider_stand':'War马待机袭击者_人类.png','rider_move':'War马行走袭击者_人类.png'}
def recover(item):
    label,name=item
    path,=(p for p in paths if '/War 马/' in p and p.endswith('/'+name))
    lfs=read(R,path)
    digest,length=re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n',lfs).groups()
    out=D/(label+'.png')
    raw=out.read_bytes()
    assert len(raw)==int(length) and hashlib.sha256(raw).hexdigest()==digest.decode(),path
    meta=parse(read(R,path+'.meta'))
    imp=meta['TextureImporter']
    assert imp['spriteMode']==2 and imp['textureSettings']['filterMode']==0
    sprites={}
    assert raw[:16] == b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
    iw, ih = struct.unpack(">II", raw[16:24])
    for sprite in imp['spriteSheet']['sprites']:
        x,y,w,h=(int(sprite['rect'][k]) for k in ('x','y','width','height'))
        assert 0<=x<=iw-w and 0<=y<=ih-h and (w,h)==(32,32)
        assert sprite['pivot']=={'x':0.5,'y':0.5}
        sprites[sprite['internalID']]=dict(name=sprite['name'],rect=[x,ih-y-h,w,h],file_id=str(sprite['internalID']))
    return meta['guid'],dict(path=path,file=out.name,sha256=digest.decode(),size=[iw,ih],pixels_per_unit=imp['spritePixelsToUnits'],sprites=sprites)

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    atlases=dict(pool.map(recover,files.items()))
asset=read(R,PATH)
definition=parse(asset)['MonoBehaviour']
assert definition['mountId']=='war_horse_human' and definition['fallbackAction']==1 and definition['fallbackAnimationKey']=='Idle'
equipment_path = 'Assets/Database/Items/Equipment/战马.asset'
equipment_guid = parse(read(R, equipment_path + '.meta'))['guid']
equipment = parse(read(R, equipment_path).replace(b'm_values: ', b'm_values: !!str '))['MonoBehaviour']
option, = parse(read(R, 'Assets/GameData/EquipmentSystem/Data/Workbench/换装工作台目录.asset'))['MonoBehaviour']['mounts']
assert option['displayName'] == '战马' and option['equipment']['guid'] == equipment_guid
assert equipment_guid == 'a9a7433e642af8744b2e309dc15ce611' and equipment['m_type'] == 5
assert equipment['m_visual']['guid'] == parse(read(R, PATH + '.meta'))['guid']
assert option['icon']['fileID'] == 0 and not option['bonusStats']['values']
assert set(equipment['m_bonusStats']['m_values']) == {'0'} and not equipment['m_formalGasAbilityCodes']
directions=('southEast','southWest','northEast','northWest')
actions={}
for action,(key,count,cycle) in zip(definition['animations'],[('Stand',12,2.4),('Move',4,0.8)],strict=True):
    assert action['mountAction']==(1 if key=='Stand' else 2) and action['secondsPerFrame']==0.2
    assert action['cycleDurationSeconds']==cycle and action['loop']==1 and action['directionMode']==0
    assert action['mountEmptyBehavior']==action['riderEmptyBehavior']==0
    rendered=[]
    for facing in directions:
        rows=[]
        for n in ('mountFrames','riderFrames'):
            refs=action[n][facing]
            assert len(refs)==count,n
            rows.append([dict(atlas=ref['guid'],**atlases[ref['guid']]['sprites'][ref['fileID']]) for ref in refs])
        assert all(a['rect']==b['rect'] and atlases[a['atlas']]['pixels_per_unit']==atlases[b['atlas']]['pixels_per_unit'] for a,b in zip(*rows)),facing
        rendered.append([dict(mount=a,rider=b) for a,b in zip(*rows)])
    actions[key]=dict(seconds_per_frame=0.2,cycle=cycle,loop=True,directions=rendered)
for data in atlases.values():
    del data['sprites']
contract=dict(source=SOURCE,mount_id=definition['mountId'],source_asset=PATH,source_asset_sha256=hashlib.sha256(asset).hexdigest(),directions=directions,fallback='Stand',atlases=atlases,actions=actions)
(D/'plain-horse-source.json').write_text(json.dumps(contract,ensure_ascii=False,indent=2)+'\n')
print('已核对四张原始图集、128 个 Sprite 引用与 64 组同画布帧。')
for g,a in atlases.items(): print(g,a['file'],a['size'],a['pixels_per_unit'],a['sha256'])
