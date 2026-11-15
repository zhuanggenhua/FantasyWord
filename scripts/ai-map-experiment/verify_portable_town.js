// 从解包目录重新读取交付 TMX，再由原版 Tiled 渲染，不依赖工程绝对素材路径。
var input=tiled.scriptArguments[0];
var target=tiled.scriptArguments[1];
var report={version:tiled.version,input:input,status:'fail'};
try {
    var map=tiled.mapFormat(/\.tmj$/.test(input)?'json':'tmx').read(input);
    if (!map) throw new Error('TMX 重读失败');
    if (!map.toImage().copy(0,0,map.width*map.tileWidth,map.height*map.tileHeight).save(target+'.png')) throw new Error('重读后渲染失败');
    report.status='pass';report.width=map.width;report.height=map.height;
    report.layers=map.layerCount;report.tilesets=map.tilesets.length;
} catch(error) { report.error=String(error);report.stack=error.stack; }
var file=new TextFile(target+'.json',TextFile.WriteOnly);
file.write(JSON.stringify(report));file.commit();
