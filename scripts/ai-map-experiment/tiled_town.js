// 项目扩展在后台编辑器中运行；纯 --evaluate 模式不支持原生 Automapping。
tiled.assetOpened.connect(function (map) {
if (!map.isTileMap || !/\/draft-town\.tmj$/.test(map.fileName.replace(/\\/g, "/"))) return;
var input = map.fileName;
var output = input.replace(/[/\\][^/\\]+$/, "");
var rules = output + "/town-rules.tmj";
Qt.callLater(function () {
try {
if (!map) throw new Error("读取城镇布局失败：" + input);
map.autoMap(rules);
var coverage = [];
function inspect(parent, prefix) {
for (var i = 0; i < parent.layerCount; ++i) {
    var layer = parent.layerAt(i);
    if (layer.isGroupLayer) { inspect(layer,prefix+layer.name+'/'); continue; }
    if (!layer.isTileLayer) continue;
    var count = 0;
    for (var y = 0; y < layer.height; ++y)
        for (var x = 0; x < layer.width; ++x)
            if (layer.tileAt(x, y)) ++count;
    coverage.push({name: prefix+layer.name, cells: count});
}
}
inspect(map,'');
map.layerDataFormat = TileMap.CSV;
var error = tiled.mapFormat("tmx").write(map, output + "/river-trade-town.tmx");
if (error) throw new Error(error);
error = tiled.mapFormat("json").write(map, output + "/river-trade-town.tmj");
if (error) throw new Error(error);
// 有限地图的子层会被 Tiled 填到整图大小；组偏移扩大空白边界。只导出固定世界窗口。
var rawImage = map.toImage();
var image = rawImage.copy(0,0,map.width*map.tileWidth,map.height*map.tileHeight);
if (!image.save(output + "/tiled-native.png")) throw new Error("Tiled 原生渲染保存失败");
var covers=[];
function reveal(parent) {
    for(var i=0;i<parent.layerCount;++i) {
        var layer=parent.layerAt(i);
        if(layer.isGroupLayer) reveal(layer);
        else if(layer.property('renderRole')==='cover') { covers.push(layer);layer.visible=false; }
    }
}
reveal(map);
if(!map.toImage().copy(0,0,map.width*map.tileWidth,map.height*map.tileHeight).save(output+'/tiled-interiors.png')) throw new Error('室内原生渲染失败');
for(var i=0;i<covers.length;++i)covers[i].visible=true;
var report = new TextFile(output + "/tiled-report.json", TextFile.WriteOnly);
report.write(JSON.stringify({version: tiled.version, automapping: true, width: map.width,
    nativeRenderSize:[rawImage.width,rawImage.height],worldViewport:[0,0,image.width,image.height],
    height: map.height, layers: coverage, source: input, rules: rules}));
report.commit();
} catch (error) {
    var failure = new TextFile(output + "/tiled-error.txt", TextFile.WriteOnly);
    failure.write(String(error) + "\n" + error.stack);
    failure.commit();
}
tiled.close(map);
tiled.trigger("Quit");
});
});
