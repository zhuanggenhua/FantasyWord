"""本地图像地图拼接：TMX 是作者源，模型只负责补全 prepare 生成的透明区域。"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops, ImageStat


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def prop(node, name, value=None):
    properties = node.find('properties')
    if value is None:
        item = None if properties is None else properties.find(f"property[@name='{name}']")
        return None if item is None else item.get('value')
    if properties is None:
        properties = ET.SubElement(node, 'properties')
    item = properties.find(f"property[@name='{name}']")
    if item is None:
        item = ET.SubElement(properties, 'property', name=name)
    item.set('value', str(value))


def read_map(path):
    root = ET.parse(path).getroot()
    if prop(root, 'localMapStitchVersion') != '1':
        raise ValueError('此命令只编辑本工具的图像地图；不能将瓦片地图当作图片拼接工程')
    return root


def images(root, folder, x=0, y=0, visible=True):
    for node in root:
        nx = x + float(node.get('offsetx', 0))
        ny = y + float(node.get('offsety', 0))
        shown = visible and node.get('visible', '1') != '0'
        if node.tag in ('group', 'imagelayer') and shown:
            if node.get('opacity', '1') != '1' or node.get('tintcolor') or node.get('blendmode', 'normal') != 'normal':
                raise ValueError('拼接作者层要求不透明度1、原色及normal混合；请用PNG透明通道表达遮罩')
        if node.tag == 'group':
            yield from images(node, folder, nx, ny, shown)
        elif node.tag == 'imagelayer' and shown:
            if not nx.is_integer() or not ny.is_integer():
                raise ValueError('像素地图的图层偏移必须是整数')
            source = node.find('image')
            path = (folder / source.get('source')).resolve()
            with Image.open(path) as src:
                im = src.convert('RGBA')
            yield node, int(nx), int(ny), path, im
        elif node.tag == 'layer':
            raise ValueError('当前拼接渲染器不处理瓦片层，请用Tiled查看混合地图')


def fingerprint(path, root):
    records = [(str(p.relative_to(path.parent)), digest(p)) for _, _, _, p, _ in images(root, path.parent)]
    return hashlib.sha256((digest(path) + json.dumps(records)).encode()).hexdigest()


def composite(records, box):
    left, top, right, bottom = box
    im = Image.new('RGBA', (right-left, bottom-top))
    for _, x, y, _, source in records:
        im.alpha_composite(source, (x-left, y-top))
    return im


def bounds(records):
    return (min(r[1] for r in records), min(r[2] for r in records),
            max(r[1]+r[4].width for r in records), max(r[2]+r[4].height for r in records))


def save_map(path, root):
    records = list(images(root, path.parent))
    box = bounds(records)
    root.set('width', str(math.ceil((box[2]-min(0, box[0]))/int(root.get('tilewidth')))))
    root.set('height', str(math.ceil((box[3]-min(0, box[1]))/int(root.get('tileheight')))))
    ET.indent(root, space='  ')
    with tempfile.NamedTemporaryFile(dir=path.parent, suffix='.tmx.tmp', delete=False) as f:
        temp = Path(f.name)
        ET.ElementTree(root).write(f, encoding='utf-8', xml_declaration=True)
    os.replace(temp, path)


def layer_id(root):
    number = int(root.get('nextlayerid'))
    root.set('nextlayerid', str(number+1))
    return str(number)


def add_image(root, folder, name, im, x, y):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', name):
        raise ValueError('图块ID只允许字母、数字、短横线和下划线')
    if any(prop(n, 'chunkId') == name for n in root.iter('imagelayer')):
        raise ValueError(f'图块ID已存在：{name}')
    assets = folder / 'assets'
    assets.mkdir(exist_ok=True)
    target = assets / f'{name}-{hashlib.sha256(im.tobytes()).hexdigest()[:12]}.png'
    if target.exists():
        raise FileExistsError(target)
    im.save(target)
    group = root.find("group[@name='地图图块']")
    node = ET.SubElement(group, 'imagelayer', id=layer_id(root), name=name,
                         offsetx=str(x), offsety=str(y), **{'class': 'WorldChunk'})
    prop(node, 'chunkId', name)
    ET.SubElement(node, 'image', source=target.relative_to(folder).as_posix(),
                  width=str(im.width), height=str(im.height))


def initialize(args):
    path = Path(args.map).resolve()
    if path.exists():
        raise FileExistsError(path)
    if args.grid < 1:
        raise ValueError('网格必须是正整数')
    path.parent.mkdir(parents=True, exist_ok=True)
    root = ET.Element('map', version='1.10', orientation='orthogonal', renderorder='right-down',
                      width='1', height='1', tilewidth=str(args.grid), tileheight=str(args.grid),
                      infinite='0', nextlayerid='4', nextobjectid='1')
    prop(root, 'localMapStitchVersion', '1')
    prop(root, 'worldMode', 'continuous')
    prop(root, 'artworkOnly', 'true')
    ET.SubElement(root, 'group', id='1', name='地图图块')
    ET.SubElement(root, 'objectgroup', id='2', name='碰撞标注', visible='0', **{'class': 'Collision'})
    ET.SubElement(root, 'objectgroup', id='3', name='地标与入口', **{'class': 'Landmarks'})
    with Image.open(args.image) as src:
        add_image(root, path.parent, args.name, src.convert('RGBA'), 0, 0)
    save_map(path, root)
    print(json.dumps({'map': str(path), 'imageSize': [src.width, src.height]}, ensure_ascii=False))


def prepare(args):
    path = Path(args.map).resolve()
    root = read_map(path)
    records = list(images(root, path.parent))
    anchor = next(r for r in records if prop(r[0], 'chunkId') == args.anchor)
    _, x, y, _, source = anchor
    w, h = source.size
    if not 0 < args.overlap < .5:
        raise ValueError('重叠率必须大于0且小于0.5')
    grid = int(root.get('tilewidth'))
    dx = max(grid, round(w*(1-args.overlap)/grid)*grid)
    dy = max(grid, round(h*(1-args.overlap)/grid)*grid)
    moves = {'east': (dx, 0), 'west': (-dx, 0), 'north': (0, -dy), 'south': (0, dy)}
    mx, my = moves[args.direction]
    x, y = x+mx, y+my
    box = (x, y, x+w, y+h)
    context = composite(records, box)
    # 旧区域由已保存地图决定，模型返回图绝不能覆盖它。
    known = context.getchannel('A')
    if any(v for i, v in enumerate(known.histogram()) if i not in (0, 255)):
        raise ValueError('已知区域含半透明像素，不能以半透明像素作为固定边界')
    unknown = ImageChops.invert(known)
    if unknown.getbbox() is None:
        raise ValueError('此邻接区域已完全覆盖，没有可扩展空间')
    out = Path(args.job).resolve()
    out.mkdir(parents=True, exist_ok=False)
    context.save(out/'context.png')
    unknown.save(out/'unknown-mask.png')
    prompt = (f'Outpaint this adjacent {args.direction} game-map region. Return exactly {w}x{h} pixels. '
              'The visible part of context.png is immutable existing world; complete only transparent pixels. '
              'Match its pixel clusters, camera, sprite proportions, palette and top-left lighting. '
              'Continue every road and watercourse across the shared boundary at the exact matching location. '
              'No UI, words, border or new perspective. '+args.brief)
    (out/'prompt.txt').write_text(prompt, encoding='utf-8')
    job = {'version': 1, 'map': os.path.relpath(path, out).replace('\\', '/'),
           'fingerprint': fingerprint(path, root), 'name': args.name,
           'direction': args.direction, 'box': list(box), 'size': [w, h],
           'contextSha256': digest(out/'context.png'), 'maskSha256': digest(out/'unknown-mask.png'),
           'prompt': prompt}
    write_json(out/'job.json', job)
    print(json.dumps(job, ensure_ascii=False))


def commit(args):
    job_path = Path(args.job).resolve()
    job = json.loads(job_path.read_text(encoding='utf-8'))
    path = (job_path.parent/job['map']).resolve()
    root = read_map(path)
    if fingerprint(path, root) != job['fingerprint']:
        raise ValueError('地图或素材已在准备后修改，必须重新prepare；拒绝覆盖Tiled手改')
    if digest(job_path.parent/'context.png') != job['contextSha256'] or digest(job_path.parent/'unknown-mask.png') != job['maskSha256']:
        raise ValueError('作业参考图或遮罩已变化')
    with Image.open(args.image) as src:
        generated = src.convert('RGBA')
    if list(generated.size) != job['size']:
        raise ValueError(f"输出尺寸不匹配：{generated.size}，要求{job['size']}；不会自动拉伸")
    with Image.open(job_path.parent/'unknown-mask.png') as src:
        unknown = src.convert('L')
    incomplete = ImageChops.multiply(ImageChops.invert(generated.getchannel('A')), unknown)
    if incomplete.getbbox():
        raise ValueError('模型未补全全部未知区域')
    before_records = list(images(root, path.parent))
    box = tuple(job['box'])
    old_region = composite(before_records, box)
    overlap_difference = ImageChops.difference(old_region.convert('RGB'), generated.convert('RGB'))
    known = ImageChops.invert(unknown)
    drift = ImageStat.Stat(overlap_difference, known).mean
    generated.putalpha(unknown)
    add_image(root, path.parent, job['name'], generated, box[0], box[1])
    after = composite(list(images(root, path.parent)), box)
    changed_known = ImageChops.multiply(ImageChops.difference(old_region, after).convert('RGB').convert('L'), known)
    if changed_known.getbbox():
        raise AssertionError('旧区域像素发生变化')
    save_map(path, root)
    report = {'status': 'pass', 'map': str(path), 'chunk': job['name'], 'inputSha256': digest(args.image),
              'knownPixelChanges': 0, 'modelOverlapDriftRgb': drift,
              'note': '保留旧区域像素不代表接缝美术已通过，需查看实际拼接图'}
    write_json(job_path.parent/'commit-report.json', report)
    print(json.dumps(report, ensure_ascii=False))


def render(args):
    path = Path(args.map).resolve()
    root = read_map(path)
    records = list(images(root, path.parent))
    box = bounds(records)
    result = composite(records, box)
    output = Path(args.output).resolve()
    result.save(output)
    write_json(output.with_suffix('.json'), {'map': str(path), 'fingerprint': fingerprint(path, root),
               'worldBounds': list(box), 'size': list(result.size), 'chunks': len(records),
               'unityVerified': False, 'collisionVerified': False, 'artworkOnly': True})
    print(json.dumps({'output': str(output), 'size': list(result.size), 'chunks': len(records)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    init = commands.add_parser('init', help='从起始图片创建可编辑TMX')
    init.add_argument('--map', required=True)
    init.add_argument('--image', required=True)
    init.add_argument('--name', default='seed')
    init.add_argument('--grid', type=int, default=8)
    init.set_defaults(run=initialize)
    plan = commands.add_parser('prepare', help='从当前TMX生成邻接区域参考图和补全作业')
    plan.add_argument('--map', required=True)
    plan.add_argument('--anchor', default='seed')
    plan.add_argument('--direction', required=True, choices=['east', 'west', 'north', 'south'])
    plan.add_argument('--overlap', type=float, default=.2)
    plan.add_argument('--job', required=True)
    plan.add_argument('--name', required=True)
    plan.add_argument('--brief', required=True)
    plan.set_defaults(run=prepare)
    accept = commands.add_parser('commit', help='接受模型补全图，只写未知区域')
    accept.add_argument('--job', required=True, help='prepare目录内的job.json')
    accept.add_argument('--image', required=True)
    accept.set_defaults(run=commit)
    draw = commands.add_parser('render', help='从当前TMX输出拼接图及边界报告')
    draw.add_argument('--map', required=True)
    draw.add_argument('--output', required=True)
    draw.set_defaults(run=render)
    args = parser.parse_args()
    args.run(args)


if __name__ == '__main__':
    main()
