"""从实际 Tiled 分组导出连续地图预览；图像缓存和运行数据都不是独立作者源。"""
from __future__ import annotations
import base64
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

from PIL import Image

import generate_town as town


def props(entry):
    return {p['name']:p['value'] for p in entry.get('properties',[])}


def build(output,verify=False,node_modules=None):
    document=json.loads((output/'river-trade-town.tmj').read_text(encoding='utf-8'))
    bundle=json.loads((output/'map-bundle.json').read_text(encoding='utf-8'))
    sys.path.insert(0,str(town.ROOT/'Temp/ai-map-forge/scripts'))
    import forge_nav
    runtime_inputs=forge_nav.runtime_inputs(forge_nav.read_blocking_set(output/'map-bundle.json'))
    width,height=document['width']*8,document['height']*8
    atlas=Image.open(output/'assets/terrain.png').convert('RGBA')
    atlas_columns=atlas.width//8
    first=next(t['firstgid'] for t in document['tilesets'] if t['source'].endswith('props.tsx'))
    prop_art={int(n.attrib['id'])+first:Image.open(output/'assets'/n.find('image').attrib['source']).convert('RGBA')
              for n in ET.parse(output/'assets/props.tsx').findall('tile')}
    image_cache={}
    def embed(image):
        stream=io.BytesIO();image.save(stream,format='PNG');encoded=base64.b64encode(stream.getvalue()).decode()
        if encoded not in image_cache:image_cache[encoded]=len(image_cache)
        return image_cache[encoded]
    def raster(layer):
        image=Image.new('RGBA',(layer['width']*8,layer['height']*8))
        for i,gid in enumerate(layer['data']):
            if not gid:continue
            n=gid-1;x=(n%atlas_columns)*8;y=(n//atlas_columns)*8
            image.alpha_composite(atlas.crop((x,y,x+8,y+8)),((i%layer['width'])*8,(i//layer['width'])*8))
        return image
    background=Image.new('RGBA',(width,height));objects=[];buildings=[]
    def add_objects(layer,ox,oy,owner=None):
        for obj in layer['objects']:
            if 'gid' not in obj:continue
            art=prop_art[obj['gid']];p=props(obj)
            objects.append({'id':obj['id'],'name':obj['name'],'image':embed(art),'x':obj['x']+ox,
                'y':obj['y']+oy-art.height,'sortY':p.get('sortY',obj['y']+oy-2),'buildingId':owner})
    for layer in document['layers']:
        if layer['type']=='tilelayer' and layer.get('visible',True):
            background.alpha_composite(raster(layer),(int(layer.get('offsetx',0)),int(layer.get('offsety',0))))
        elif layer['type']=='objectgroup' and layer.get('visible',True):add_objects(layer,0,0)
        elif layer['type']=='group':
            p=props(layer);ox,oy=layer.get('offsetx',0),layer.get('offsety',0)
            cover=Image.new('RGBA',(p['widthTiles']*8,p['heightTiles']*8));geometry={};walls=[];furniture=[]
            for child,cx,cy,_ in town.tiled_layers([layer]):
                role=props(child).get('renderRole')
                if child['type']=='tilelayer':
                    if role=='cover':cover.alpha_composite(raster(child),(int(cx-ox),int(cy-oy)))
                    elif child.get('visible',True):background.alpha_composite(raster(child),(int(cx),int(cy)))
                elif role=='furniture':
                    add_objects(child,cx,cy,p['buildingId'])
                    for obj in child['objects']:
                        value=props(obj)
                        if value.get('solid'):
                            furniture.append({'x':obj['x']+cx+obj['width']/2,
                                'y':obj['y']+cy+value.get('footprintOffsetY',-2)})
                elif role=='geometry':
                    for obj in child['objects']:
                        geometry[obj['type']]={'x':obj['x']+cx,'y':obj['y']+cy,
                            'width':obj.get('width',0),'height':obj.get('height',0)}
                elif role=='collision':
                    walls.extend({'x':obj['x']+cx,'y':obj['y']+cy,'width':obj['width'],'height':obj['height']}
                                 for obj in child['objects'])
            buildings.append({'id':p['buildingId'],'name':layer['name'],'role':p['用途'],
                'x':ox,'y':oy,'width':cover.width,'height':cover.height,'cover':embed(cover),
                'geometry':geometry,'walls':walls,'furnitureProbes':furniture})
    # 验证角色使用已有原包静态帧，不把测试方块冒充游戏人物。
    pack=town.ROOT/'Assets/Art/KrishnaPalacio/MINIFANTASY - Dungeon'
    actor_art=town.shared.SourceArt(pack,town.TOWN_SCENE).named_sprite('HumanBaseIdle.png','HumanBaseIdle_0')
    actor=embed(actor_art['image'])
    background_index=embed(background)
    scene={'mapId':'river-trade-town','source':'river-trade-town.tmj','sourceSha256':town.shared.sha(output/'river-trade-town.tmj'),
        'width':width,'height':height,'background':background_index,'actor':actor,'actorAnchor':[15.5,19],
        'bundle':bundle,'runtimeInputs':runtime_inputs,'buildings':buildings,'objects':objects,
        'actorSource':{'path':str(actor_art['texture'].relative_to(town.ROOT)),
                       'sha256':town.shared.sha(actor_art['texture']),'sprite':actor_art['name']}}
    write_preview(output,scene,image_cache,verify,node_modules)


def write_preview(output,scene,image_cache,verify=False,node_modules=None,title='河渡镇'):
    """将实际地图工程导出的场景发布为离线预览；不持有另一套地图作者数据。"""
    import html as html_module
    preview=output/'preview';preview.mkdir(exist_ok=True)
    town.shared.write_json(preview/'town-scene.json',scene)
    runtime=town.ROOT/'Temp/ai-map-forge/references/runtime/map-runtime.mjs'
    source=Path(__file__).with_name('town_preview_runtime.js').read_text(encoding='utf-8')
    module=base64.b64encode(runtime.read_bytes()).decode()
    encoded=json.dumps(scene,ensure_ascii=True,separators=(',',':')).replace('<','\\u003c')
    images=json.dumps(['data:image/png;base64,'+v for v in image_cache],separators=(',',':'))
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>河渡镇 · 连续开放地图</title>
<style>*{box-sizing:border-box}body{margin:0;background:#171b18;color:#e9e6d4;font:15px system-ui}header{max-width:1000px;margin:auto;padding:14px 20px}h1{font-size:21px;margin:0 0 6px}p{margin:6px 0;color:#c2c6b5}button{border:1px solid #687459;background:#303b2a;color:#fff;padding:6px 13px;cursor:pointer}main{max-width:1000px;margin:auto;padding:0 20px 15px}canvas{display:block;width:100%;height:auto;image-rendering:pixelated;background:#121810;border:1px solid #66704b;touch-action:none}#status{display:inline-block;margin-left:14px;color:#e2ce87}</style>
<header><h1>河渡镇 · 同一世界内直接进出建筑</h1><p>WASD / 方向键移动，点击地面寻路，滚轮缩放。走进门洞揭开本栋屋顶，离开后恢复。</p><button id="overview">全镇总览 / 跟随角色（M）</button><button id="reset">返回出生点（R）</button><span id="status">正在载入</span></header><main><canvas id="map" width="960" height="640" tabindex="0"></canvas></main>
<script type="module">'''+f"const API=await import('data:text/javascript;base64,{module}');\nconst SCENE={encoded};\nconst IMAGE_URLS={images};\n"+source+'</script></html>'
    html=html.replace('河渡镇',html_module.escape(title))
    (preview/'preview.html').write_text(html,encoding='utf-8')
    if verify:
        env=os.environ.copy()
        if node_modules:env['NODE_PATH']=str(node_modules)
        subprocess.run(['node',str(Path(__file__).with_name('verify_town_preview.mjs')),str(preview)],
                       env=env,cwd=town.ROOT,check=True,timeout=180)
    town.shared.write_json(output/'preview-source.json',{'mapSha256':scene['sourceSha256'],
        'runtimeSha256':town.shared.sha(runtime),'actorSource':scene['actorSource'],
        'previewSha256':town.shared.sha(preview/'preview.html'),'buildingGroups':len(scene['buildings'])})
