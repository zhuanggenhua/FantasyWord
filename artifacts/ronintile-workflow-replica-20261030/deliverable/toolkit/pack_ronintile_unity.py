"""按原导出模板提供的文件列表生成真实Unity tar.gz包，不改模板内容。"""
import base64
import io
import json
from pathlib import PurePosixPath
import sys
import tarfile

entries = json.load(sys.stdin)
output = io.BytesIO()
names = set()
with tarfile.open(mode='w:gz', fileobj=output) as archive:
    for entry in entries:
        path = PurePosixPath(entry['name'])
        if path.is_absolute() or '..' in path.parts or str(path) in names:
            raise ValueError('非法或重复的归档路径：'+str(path))
        names.add(str(path))
        data = bytes(entry['bytes'])
        info = tarfile.TarInfo(str(path))
        info.size = len(data)
        info.mode = 0o644
        info.mtime = 0
        archive.addfile(info, io.BytesIO(data))
sys.stdout.write(base64.b64encode(output.getvalue()).decode('ascii'))
