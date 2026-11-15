"""独立检查原引擎实际工程、分层贴图和归档内容，不以命令成功代替文件验收。"""
from __future__ import annotations
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile
import json5

import numpy as np
from PIL import Image


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def image(url):
    return Image.open(io.BytesIO(base64.b64decode(url.split(',', 1)[1]))).convert('RGBA')


def check_package(path):
    with tarfile.open(path, 'r:gz') as archive:
        files = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    assert files and path.read_bytes()[:2] == b'\x1f\x8b'
    groups = {name.rsplit('/', 1)[0] for name in files}
    for group in groups:
        assert re.fullmatch(r'[0-9a-f]{32}', group), group
        assert group+'/pathname' in files and group+'/asset.meta' in files
        meta = files[group+'/asset.meta'].decode('utf-8')
        assert re.search(r'guid:\s*'+group+r'\b', meta), group
        assert files[group+'/pathname'].decode('utf-8').startswith('Assets/ronintile')
        if group+'/asset' in files and files[group+'/asset'].startswith(b'\x89PNG'):
            Image.open(io.BytesIO(files[group+'/asset'])).verify()
    return {'files': len(files), 'guidGroups': len(groups), 'gzipTar': True, 'guidMetadataMatches': True}


def check_fixture(folder):
    report = load(folder/'workflow-report.json')
    assert report['status'] == 'pass' and not report['errors'] and not report['blockedRequests']
    history = [s for s in report['trace'] if s['op'] in ['undo', 'redo']]
    assert [(s['op'], s['placementsBefore'], s['placementsAfter']) for s in history] == [
        ('undo', 776, 768), ('redo', 768, 776)]
    before, after = load(folder/'checkpoint.json'), load(folder/'project.json')
    fields = ['tilewidth', 'tileheight', 'tileshape', 'sources', 'tiles',
              'set', 'set_regions', 'sandbox_layers', 'sandbox']
    for field in fields:
        assert before[field] == after[field], field
    # 原版加载按逆序重建关系，保存时重新编号；按引用边比较完整关系内容。
    def relation_graph(document):
        return sorted(json.dumps({'tile': edge['tile'], 'other': edge['other'],
                                  'data': document['relations'][edge['r']]}, sort_keys=True)
                      for edge in document['tileRelations'])
    assert relation_graph(before) == relation_graph(after), 'relation graph changed'
    assert len(before['relations']) == len(after['relations'])
    exported = load(folder/'exports/map-JSON/map-JSON.txt')
    atlas = Image.open(folder/'exports/map-JSON/map-JSON.png').convert('RGBA')
    reconstructed = Image.new('RGBA', (exported['map_width']*8, exported['map_height']*8))
    positions = sum(len(layer['positions']) for layer in exported['layers'])
    assert positions == len(after['sandbox']) == 776
    for layer in exported['layers']:
        for p in layer['positions']:
            x, y = p['id'] % 8*8, p['id']//8*8
            reconstructed.alpha_composite(atlas.crop((x, y, x+8, y+8)), (p['x']*8, p['y']*8))
    native = Image.open(folder/'map-render.png').convert('RGBA')
    exported_png = Image.open(folder/'exports/map-Image.png').convert('RGBA')
    assert native.tobytes() == exported_png.tobytes()
    difference = int(np.abs(np.array(reconstructed, dtype=np.int16)-np.array(native, dtype=np.int16)).max())
    assert difference <= 1, difference
    requested = {(s['domain'], s['format']) for s in report['trace'] if s['op'] == 'export'}
    assert requested == {(d, f) for d in ['map', 'set'] for f in ['JSON', 'Image', 'Unity', 'Godot', 'GMS2', 'GMS2 (2.3.0)', 'Defold']}
    format_files = {}
    for domain in ['map', 'set']:
        for label in ['JSON', 'Image', 'Unity', 'Godot', 'GMS2', 'GMS2-2.3.0', 'Defold']:
            name = domain+'-'+label
            target = folder/'exports'/name
            if label in ['Image', 'Unity']:
                target = target.with_suffix('.png' if label == 'Image' else '.unitypackage')
                assert target.is_file(), target
                matches = [target]
            else:
                patterns = {'JSON': ['*.txt', '*.png'], 'Godot': ['*.tres', '*.png', '*.import'],
                            'GMS2': ['*.yyp', '*.yy', '*.png'], 'GMS2-2.3.0': ['*.yyp', '*.yy', '*.png'],
                            'Defold': ['*.tilesource', '*.png']}[label]
                if domain == 'map' and label == 'Godot': patterns.append('*.tscn')
                if domain == 'map' and label == 'Defold': patterns.append('*.tilemap')
                for pattern in patterns:
                    assert list(target.rglob(pattern)), (target, pattern)
                matches = [p for p in target.rglob('*') if p.is_file()]
                if label == 'JSON': load(target/(name+'.txt'))
            format_files[name] = [str(p.relative_to(folder)) for p in matches]
    for file in (folder/'exports').rglob('*'):
        if not file.is_file():
            continue
        assert file.stat().st_size > 0, file
        if file.suffix.lower() == '.png':
            Image.open(file).verify()
        elif file.suffix in ['.yy', '.yyp']:
            # GameMaker 2.3模板保留尾逗号，使用支持该语法的解析器读取。
            json5.loads(file.read_text(encoding='utf-8'))
    packages = {f.name: check_package(f) for f in (folder/'exports').glob('*.unitypackage')}
    assert len(packages) == 2
    return {'status': 'pass', 'roundTripFields': fields, 'relationGraphEqual': True,
            'relationIdsMayReorder': True, 'placements': positions, 'undoRedo': history,
            'nativePngEqualsImageExport': True, 'atlasReconstructionMaxChannelDifference': difference,
            'formatsChecked': len(requested), 'formatFiles': format_files, 'unityPackages': packages,
            'targetEngineRuntimeVerified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--blob', default='full-reference-run-v4')
    parser.add_argument('--wang', default='wang-reference-run-v2')
    args = parser.parse_args()
    result = {'status': 'pass', 'blob': check_fixture(args.root/args.blob), 'wang': check_fixture(args.root/args.wang),
              'unityRuntimeVerified': False}
    (args.root/'workflow-verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'status': 'pass', 'formatsPerFixture': result['blob']['formatsChecked'],
                      'blobPlacements': result['blob']['placements'], 'wangPlacements': result['wang']['placements']}))


if __name__ == '__main__':
    main()
