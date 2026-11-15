// 项目扩展在后台编辑器中运行；纯 --evaluate 模式不支持原生 Automapping。
var output = tiled.projectFilePath.replace(/[/\\][^/\\]+$/, "");
var input = output + "/draft-town.tmj";
var rules = output + "/town-rules.tmj";
tiled.assetOpened.connect(function (map) {
if (map.fileName.replace(/\\/g, "/") !== input.replace(/\\/g, "/")) return;
try {
if (!map) throw new Error("读取城镇布局失败：" + input);
map.autoMap(rules);
var coverage = [];
for (var i = 0; i < map.layerCount; ++i) {
    var layer = map.layerAt(i);
    if (!layer.isTileLayer) continue;
    var count = 0;
    for (var y = 0; y < map.height; ++y)
        for (var x = 0; x < map.width; ++x)
            if (layer.tileAt(x, y)) ++count;
    coverage.push({name: layer.name, cells: count});
}
map.layerDataFormat = TileMap.CSV;
var error = tiled.mapFormat("tmx").write(map, output + "/river-trade-town.tmx");
if (error) throw new Error(error);
error = tiled.mapFormat("json").write(map, output + "/river-trade-town.tmj");
if (error) throw new Error(error);
var image = map.toImage();
if (!image.save(output + "/tiled-native.png")) throw new Error("Tiled 原生渲染保存失败");
var report = new TextFile(output + "/tiled-report.json", TextFile.WriteOnly);
report.write(JSON.stringify({version: tiled.version, automapping: true, width: map.width,
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
