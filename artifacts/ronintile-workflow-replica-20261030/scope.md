# RoninTile原素材流程本地执行与对照

用户目标：复刻参考的完整素材地图流程，使用工程MiniFantasy素材；连续室内外，不切场景。旧AI整图扩图不在本轮验收链。

精确来源：用户提供的FrameRonin skill ZIP；当前在线RoninTile的实际已加载脚本`https://frameronin.com/ronintile/assets/index-5sEpM8Gi.js`，SHA256为5d419daadf2a3a5480cb83add497f65b82cdb5ce29ed32bc5afe38d70ca5dee4，原引擎版本2.1.0-pro。111个模块从公开脚本字面量静态提取，完整浏览器脚本和48个已加载资源现保留在本任务reference-engine与交付包engine参考区。不是旧GitHub主干的MapStitch.tsx。

环境：本机隔离Chromium+Python；素材仅本机读取；服务仅监听127.0.0.1，外部请求拒绝；无网站Key、账号设置或Unity Editor操作。

## 执行方式

采用原引擎本地运行，由自有CLI调用原版导出API完成流程；不把这个动作声称为独立重写算法。原算法、原生成器、原工程格式和原导出模板不改。新增CLI只负责文件输入、命令编排、结果保存与证据报告。完整GUI不是另造的新界面，原版UI只用作本地干净参考。

本地工程作者源是原版project.json：sources、tiles、relations、tileRelations、set、sandbox_layers、sandbox。Tiled和运行预览都是从当前原工程导出/转换的派生数据，不取代原工程。

## 完整流程对账范围

|阶段|原版入口|本地执行入口|验收|
|---|---|---|---|
|新建/像素规格|newData/setTileSize|recipe初始参数|8px、正交、原版本|
|源图导入和切分|imageToSources/TileBase|import|来源PNG哈希、非空块数量、逐块像素|
|图块关系定义|BorderSetBlob/Wang/TileRelation|relation|12槽原图引用与变换记录|
|自动边界|buildBordersBlob/Wang|build-borders|原生成器产物与关系保存|
|物件组合|groupTilesAsProp|prop|构件相对位置和整组铺设|
|图层/排序/显隐|add/edit/reorderLayerSandbox|layer及call|名称、可见性和各层原数据|
|绘制与自动铺图|drawTilesSandbox/paintTilesSandbox|draw/paint/stamp|同源Tile引用、邻接与擦除行为|
|撤销/恢复|saveUndoState/performUndo/Redo|每步事务及undo/redo|原版状态恢复|
|工程保存重读|saveData/loadData|save/reload|源图、图块、关系、分层位置均保留|
|导出|exportPackageSet/Map及原XML模板|export|实际文件、贴图和坐标，不能只看日志|
|项目连续室内|原RoninTile无室内揭顶玩法|本项目既有地图语义和预览|必须另验，不声称来自参考|

原引擎79个导出函数也通过受限call步骤暴露；参数只接受JSON数据和显式图块/源/类引用，不能注入JS。同步区域、代理、替换和变体等操作仍调用原函数，是否完成对应验收以覆盖矩阵为准，不以API存在冒充已验证。

本轮不改Unity生产框架或生命周期；没有框架迁移。原源代码不作为独立开发作品发布，已下载依赖来源和哈希保留。
