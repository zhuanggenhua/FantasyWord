"""验收实际保存的连续城镇：原素材建筑、同图进出、街道回环及来源未改动。"""
from __future__ import annotations

import argparse
from heapq import heappop, heappush
import json
from pathlib import Path
import sys
import zipfile

import numpy as np

import generate_town as town

sys.path.insert(0,str(town.ROOT/'Temp/ai-map-forge/scripts'))
import forge_nav


def check(output):
    """以当前 TMJ 和导出的同源碰撞包为准，输出可复核的验收记录。"""
    read=lambda name:json.loads((output/name).read_text(encoding='utf-8'))
    plan=read('layout.json'); document=read('river-trade-town.tmj'); audit=read('source-audit.json')
    qa=read('preview/preview-qa.json')
    if qa['status']!='pass' or qa['final']['sourceSha256']!=town.shared.sha(output/'river-trade-town.tmj'):
        raise ValueError('浏览器验收未通过或没有覆盖当前地图')
    if read('nav/nav-report.json')['status']!='pass':raise ValueError('当前寻路检查未通过')
    layers={v['name']:v for v in document['layers']}
    rows,cols=plan['height'],plan['width']
    original_hashes=[]
    for entry in audit['originals']:
        actual=town.shared.sha(town.ROOT/entry['path'])
        if actual!=entry['sha256']:raise ValueError('原素材发生变化：'+entry['path'])
        original_hashes.append({'path':entry['path'],'sha256':actual,'unchanged':True})

    art=town.shared.SourceArt(town.TOWN,town.TOWN_SCENE)
    source=town.shared.read_scene(art,town.TOWN_SCENE)
    gids={entry['gid']:tuple(entry['sprite']) for entry in audit['tiles']}
    groups={dict((p['name'],p['value']) for p in g.get('properties',[]))['buildingId']:g
        for g in document['layers'] if g['type']=='group'}
    if set(groups)!={v['id'] for v in plan['buildings']}:raise ValueError('建筑分组与作者布局不符')
    building_checks=[]
    for building in audit['buildings']:
        left,bottom,right,top=building['source_bounds']
        count=0;door_tiles=[]
        group=groups[building['id']]
        x0,y0=group.get('offsetx',0)/8,group.get('offsety',0)/8
        door_point=next((o,ox,oy) for v,ox,oy,_ in town.tiled_layers([group])
            if v['type']=='objectgroup' for o in v['objects'] if o['type']=='ExteriorPoint')
        current_door=[(door_point[0]['x']+door_point[1])/8,(door_point[0]['y']+door_point[2])/8]
        if not dict((p['name'],p['value']) for p in group['properties']).get('continuousInterior'):
            raise ValueError('建筑未声明同图室内')
        local_layers={v['name']:v for v in group['layers']}
        for original,target in town.BUILDING_LAYERS.items():
            for (x,y),(sprite,_) in source[original].items():
                if not (left<=x<=right and bottom<=y<=top):continue
                if sprite['name'].startswith(('Sidewalk','Fence','Dirt')):continue
                dx,dy=x-left,top-y
                if any(part in sprite['name'] for part in ('_SquareDoor_','_PointedDoor_')):
                    door_tiles.append((dx+x0,dy+y0))
                if town.opens_door(sprite['name'],dx,(current_door[0]-x0)*8):continue
                placed_layers=[v for v in group['layers'] if v['type']=='tilelayer' and
                    (v['name']==target or dict((p['name'],p['value']) for p in v.get('properties',[])).get('sourceLayer')==target)]
                actual=[v['data'][dy*v['width']+dx] for v in placed_layers if v['data'][dy*v['width']+dx]]
                if len(actual)!=1 or gids.get(actual[0])!=sprite['key']:
                    raise ValueError(f"{building['name']} 的 {target} 瓦片与原样组合不一致：{dx},{dy}")
                count+=1
        if count!=building['copied_cells']:raise ValueError('建筑复制数量不符')
        if door_tiles:
            front=max(y for _,y in door_tiles)
            bottom_tiles=[x for x,y in door_tiles if y==front]
            expected=[(min(bottom_tiles)+max(bottom_tiles)+1)/2,front+1.5]
            if expected!=current_door:
                raise ValueError(f"{building['name']} 门口未对准原素材门：{current_door} != {expected}")
        else:expected=current_door
        building_checks.append({'id':building['id'],'name':building['name'],'tiles':count,
            'original_sprite_composition':'pass','door_tile_position':expected,'door_alignment':'pass',
            'opened_door_tiles':building['opened_door_tiles'],'interior_furniture':building['interior_furniture']})

    model=forge_nav.read_blocking_set(output/'map-bundle.json').model()
    grid=forge_nav.build_grid(model)
    roads=np.array(layers['道路']['data']).reshape(rows,cols)!=0
    paved=roads[(grid.ys//8).astype(int)[:,None],(grid.xs//8).astype(int)[None,:]]
    valid=grid.valid & paved
    moves=forge_nav.moves_from_mask(valid) & grid.moves
    offsets=[(1,0,1),(0,1,2),(-1,0,4),(0,-1,8)]

    def path(a,b,closed=()):
        """在原碰撞网格上沿已铺街道行走，禁止借用草地作为捷径。"""
        sr,sc=grid.node_of(*a);tr,tc=grid.node_of(*b)
        if not valid[sr,sc] or not valid[tr,tc]:return None
        blocked=set(closed)
        todo=[(abs(sc-tc)+abs(sr-tr),0,sr,sc)]
        best={(sr,sc):0};previous={}
        while todo:
            _,cost,r,c=heappop(todo)
            if cost!=best[(r,c)]:continue
            if (r,c)==(tr,tc):
                found=[(r,c)]
                while found[-1]!=(sr,sc):found.append(previous[found[-1]])
                return [(float(grid.xs[c]),float(grid.ys[r])) for r,c in reversed(found)]
            for dx,dy,bit in offsets:
                nr,nc=r+dy,c+dx
                if not (int(moves[r,c]) & bit) or (nr,nc) in blocked:continue
                distance=cost+1
                if distance<best.get((nr,nc),float('inf')):
                    best[(nr,nc)]=distance;previous[(nr,nc)]=(r,c)
                    heappush(todo,(distance+abs(nc-tc)+abs(nr-tr),distance,nr,nc))
        return None

    points={plan['spawn']['id']:[v*8 for v in plan['spawn']['point']]}
    for entry,ox,oy,building in town.tiled_layers(document['layers']):
        if building and entry['type']=='objectgroup':
            for obj in entry['objects']:
                if obj['type']=='ExteriorPoint':points[building]=[obj['x']+ox,obj['y']+oy]
    points.update({v['id']:[p*8 for p in v['point']] for v in plan['points']})
    for bridge in plan['bridges']:
        x,y,w,h=bridge['rect'];points[bridge['id']]=[(x+w/2)*8,(y+h/2)*8]
    for key,point in points.items():
        if not bool(model.valid(*point)):raise ValueError('检查点本身不可站立：'+key)
        r,c=grid.node_of(*point)
        if not valid[r,c]:raise ValueError('检查点未接到已铺街道：'+key)
    routes=[]
    for route in plan['representative_routes']:
        segments=[]
        for a,b in zip(route['sequence'],route['sequence'][1:]):
            result=path(points[a],points[b])
            if not result:raise ValueError(f'街道路由不通：{a} -> {b}')
            segments.append({'from':a,'to':b,'length_px':len(result)-1,'path_px':result})
        length=sum(v['length_px'] for v in segments)
        routes.append({**route,'status':'pass','street_only':True,'length_px':length,
            'seconds_at_32px_s':round(length/32,1),'segments':segments})
    # 在每座桥的中央切断整个净宽，验证另一座桥提供独立回路。
    cuts={}
    for bridge in plan['bridges']:
        x,y,w,h=bridge['rect'];mx=(x+w/2)*8
        cuts[bridge['id']]={(r,c) for r,py in enumerate(grid.ys) for c,px in enumerate(grid.xs)
                           if mx<=px<mx+1 and (y+1)*8<=py<(y+h-1)*8}
    origin=points[plan['spawn']['id']];destination=points['market_square']
    for key,closed in cuts.items():
        if path(origin,destination,closed) is None:raise ValueError('关闭单桥后另一座桥不能回通：'+key)
    if path(origin,destination,set.union(*cuts.values())) is not None:
        raise ValueError('关闭两座桥后仍存在跨河街道，碰撞或桥梁规划有误')
    report={'status':'pass','source':'river-trade-town.tmj','map_sha256':town.shared.sha(output/'river-trade-town.tmj'),
        'building_checks':building_checks,'standing_checkpoints':len(points),'routes':routes,
        'continuous_world':{'mapId':qa['final']['mapId'],'buildings_walked':len(qa['checks']),
            'invalid_steps':qa['final']['invalidSteps'],'portals':qa['final']['portals'],
            'page_navigations':len(qa['pageNavigations']),'keyboard_and_click':qa['input']},
        'bridges':{'single_bridge_closed_still_connected':True,'both_closed_disconnect_banks':True,
                   'clearance_tiles':3},'original_assets':original_hashes,
        'limits':['这是同图室内外作者工具与离线预览，未验证 Unity、NPC/交易/任务和正式角色动画。',
                  '墙体和家具使用实际设计碰撞，围栏按瓦片阻挡；非 Unity 碰撞验收。',
                  '路线时间仅按32px/s计算步行长度，不含交互和停留；未代表玩家试玩评价。']}
    town.shared.write_json(output/'design-review.json',report)
    return report


def package(output,report):
    """整理私有项目内的可移动地图包；不上传素材，不自动安装 Unity 插件。"""
    town.shared.write_json(output/'river-trade-town.tiled-project',{'folders':['.'],
        'extensionsPath':'project-extensions','automappingRulesFile':'town-rules.tmj'})
    lines=['# 河渡贸易镇：同图室内外连续空间','',
        '采用现有 MiniFantasy Towns I / Forgotten Plains 素材；原版 Tiled 1.12.2 实际执行 Automapping、保存 TMX/TMJ 和原生渲染。',
        '设计：桥头 → 市场棚亭和水井 → 北侧商旅街；南侧转入庭院、住宅支巷，经南桥返回西岸。西岸旧石塔与仓库构成独立短线。','',
        '## 查看和编辑','',
        '- `town-overview.png`：原生地图渲染的2倍最近邻放大，640×480逻辑像素，80×60格。',
        '- 用 Tiled 打开 `river-trade-town.tmx` 或 `river-trade-town.tiled-project`；贴图和 TSX 全部采用包内相对路径。',
        '- `town-interiors.png`：同一张地图临时揭开所有建筑遮挡后的原生作者检查图，不是另一张室内地图。',
        '- `preview/preview.html`：双击打开，WASD/方向键移动、点击寻路、滚轮缩放、M总览。角色采用原包静态帧。',
        '- 从门洞直接走进原地房间，只揭开本栋屋顶和遮挡立面；离开恢复，世界坐标和地图均不切换。',
        '- `规划输入`、`水域输入` 是隐藏的概念层；`town-rules.tmj` 是由原包固定朝向规则转换的原生自动铺图规则。',
        '- 每栋建筑是原生 Tiled 分组，内部包含室内地板、室内墙体、室内家具、外观叠层、屋顶、墙体碰撞、空间与入口。',
        '- 整栋移动：选择建筑组，修改组偏移（像素，建议8的整数倍）；所有子层、家具、入口、室内区域和碰撞一起移动。',
        '- 看室内：隐藏组内 renderRole=cover 的外观/屋顶/阴影子层。运行时按室内区域自动执行，无需手动切层。',
        '- 改墙、门洞或家具时，同时检查本栋的墙体碰撞和家具 footprint 属性。隐藏屋顶不改变任何碰撞。',
        '- `建筑入口与探索点`、`碰撞规划` 是城镇公共设计层；各栋门洞和室内行走点位于自己的组内。',
        '- 当前浏览器预览是本次导出的快照，Tiled 手动保存不会自动刷新；保留手改TMX，不要用从布局重建的命令覆盖它。','',
        '## 当前验证','',
        '- 10栋建筑使用原示例外观瓦片，打开原门瓦片位置的真实通道，室内采用原包地板、墙和家具。',
        '- 离线24个室内/外目标全部可达；浏览器逐栋实际行走进出，验证屋顶隐藏/恢复、后墙和家具碰撞。',
        '- 浏览器检查每个移动步长不超过预算，地图ID和内容哈希始终相同，传送入口、页面导航和外部请求均为0。',
        '- 下列3条路线在实际碰撞网格上只沿已铺街道通过，不借草地绕过断路：']
    lines.extend(f"- {r['name']}：{r['length_px']}px，约{r['seconds_at_32px_s']}秒纯步行。" for r in report['routes'])
    lines+=['- 两座桥分别关闭时另一座仍连通；同时关闭会隔断两岸，证明双桥构成真实回路。',
        '- 原素材 SHA256 回读一致。以上验证是作者工具和离线地图层验证，未启动 Unity。','',
        '## 导入 Unity 的下一步','',
        '可以用 SuperTiled2Unity 导入 TMX：https://github.com/Seanba/SuperTiled2Unity 。',
        '将地图和整个 assets 目录一起放入 Unity 后，可由导入器创建 Tilemap。此包使用派生图集；属性中的原始 GUID/fileID 用于追溯，不会自动变回原包 RuleTile 或 Prefab。',
        '本轮未安装导入器，未验证本工程 Unity/URP 2D 的兼容性、像素采样、排序和碰撞。自动揭顶在浏览器预览中实现，导入Unity后还需由正式表现组件消费同一建筑组和室内区域；不能称为Unity功能已接入。',
        '仅地面层；多楼层、NPC、交易、任务和大世界流式加载不在本轮范围。室内外连通不需要场景切换。','',
        '## 在当前工作区复现','',
        '从工程根目录运行（新输出目录不可已存在；不打开 Unity）：','',
        '```powershell',
        'python -X utf8 scripts/ai-map-experiment/generate_town.py --output-dir artifacts/ai-town-seamless-rerun --check --node-modules C:/Users/zhuagenbao/AppData/Roaming/npm/node_modules/clawdbot/node_modules',
        'python -X utf8 scripts/ai-map-experiment/review_town.py --output-dir artifacts/ai-town-seamless-rerun',
        '```','',
        '本机 Tiled 缓存：`Temp/tiled-1.12.2/app/tiled.exe`；原版 MSI 下载地址和 SHA256 记录在同级 `source.json`。Python 依赖 Pillow、PyYAML、NumPy。',
        '原生 Automapping 需要编辑器文档，纯 `--evaluate` 对分离地图不支持此操作。因此生成脚本通过 CLI 启动隐藏 Tiled 进程，在本任务便携副本内加载扩展，输出后自动退出；不用鼠标铺图。',
        '规则选择第一静态帧，未接入原包动画；地图不包含 AI 绘制或替代素材。',
        '素材仅用于当前已授权的本地工程实验，不应把含有商业素材的 ZIP 公开分发。','']
    (output/'README.md').write_text('\n'.join(lines),encoding='utf-8')
    names=['river-trade-town.tmx','river-trade-town.tmj','river-trade-town.tiled-project',
        'town-rules.tmj','layout.json','source-audit.json','rule-coverage.json','design-review.json',
        'README.md','town-overview.png','town-interiors.png','preview/preview.html','preview/preview-qa.json','preview-source.json']
    files=[output/name for name in names]+sorted((output/'assets').rglob('*'))
    destination=output/'river-trade-town-unity-import.zip'
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            if path.is_file():archive.write(path,path.relative_to(output).as_posix())
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip():raise ValueError('打包校验失败')
    town.shared.write_json(output/'package-report.json',{'status':'pass','file':destination.name,
        'bytes':destination.stat().st_size,'sha256':town.shared.sha(destination),'unity_verified':False})


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output-dir',type=Path,required=True)
    output=parser.parse_args().output_dir.resolve()
    report=check(output);package(output,report)
    print(json.dumps({'status':'pass','buildings':len(report['building_checks']),
        'street_routes':len(report['routes']),'bridges':report['bridges']}))
