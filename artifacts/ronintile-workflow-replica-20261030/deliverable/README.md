# RoninTile 原素材地图流程，本地 CLI 版

这次使用工程已有的 MiniFantasy 原 PNG 和 Sprite 切片。没有 AI 重绘整图、邻图扩图，也没有向第三方上传素材。最终地图是 96×72 个 8px 瓦片，154 个原 Sprite、10,792 个实际放置、146 个原生图层；10 栋建筑和室内共用世界坐标。

原 skill 的两个入口须区分：**“地图拼接”是场景整图 AI 扩展；“Tile处理 / RoninTile”才是既有素材切图和瓦片铺图。** 本轮按用户明确要求复刻后者的素材流程。原 skill 对 RoninTile 只写了载入、设尺寸、铺图、保存和导出，不含详细关卡设计方法；本次布局由本助手编排成配方，不声称原工具自带 AI 城镇规划。

执行方式必须说清楚：这是**当前 RoninTile 原版引擎的本地执行 + 自有 CLI、文件宿主和本项目连续室内预览**。没有独立重写它的算法，也没有复刻 FrameRonin 全站。原网页的 111 个业务模块及导出模板保持原内容。来源 URL、版本与 SHA256 在 `toolkit/ronintile-engine-lock.json`，只在本机保存和使用，不作为自研源码发布。

## 直接看和编辑

- `map/preview/preview.html`：浏览器直接打开。WASD/方向键移动，点击寻路，进门揭开本栋屋顶，出门恢复；没有室内场景切换。
- `map/stoneford.tmx`、`map/stoneford.tmj`：用 Tiled 编辑。146 个真实瓦片层，另有隐藏的碰撞、建筑空间与门洞两个标注层。不是一张整图背景。
- `native/project.json`：原生作者工程，保存源图、图块、关系、素材集、分层和每个放置位置；图像数据已内嵌。`extra.workflow` 是本项目增加的建筑和碰撞语义。
- `native/exports/stoneford-unity.unitypackage`：原模板导出的真实 tar.gz 资源包；已检查内部 GUID/路径/图片。**尚未启动 Unity 验证导入或运行。**

Tiled 文件、预览和图集均从原生工程实际导出结果生成。手改 Tiled 不会自动回写 `project.json`，也不会自动更新浏览器预览。不要将两边同时作为作者源。修改门、墙或建筑时，要同步原生工程 `extra.workflow` 对应碰撞/空间语义，再生成预览。

## 完整素材链路

1. 原 PNG + `.meta` 的 GUID、fileID、rect 提取真实 Sprite，保留来源哈希。
2. 原版 `imageToSources` 按 8px 切图；非整倍数物件按原规则补足格子，透明空块跳过。
3. 用原 `groupTilesAsProp` 组合物件；9×14 酒桶实测由 4 格组成，两次整组铺设共 8 格。
4. 原 `buildBordersBlob/Wang` 创建边界关系，再配置 12 个素材槽、旋转、翻转和合成参数。当前 CLI 工作流明确提供全部槽；不是依赖缺失的默认占位图片。
5. 对本素材包已有的预绘边界，用原 `replaceBlobBorder` 绑定；最终地图的所有实际放置均引用原始 Base 素材。
6. 原版分层、`draw/paint` 自动邻接铺图、物件印章；原生撤销/恢复。
7. 原版保存、重读。关系编号会重排，验证比较完整引用图，不把编号变化当作内容变化。
8. 原版地图/素材集导出：JSON、Image、Unity、Godot、GMS2、GMS2 2.3、Defold，各 7 种。
9. 从原生 JSON+图集独立重建并对账；再派生 Tiled、碰撞导航和连续室内预览。

最后一项的揭顶、移动与碰撞是本项目新增功能，不是 RoninTile 自带玩法。

## 重放已经验收的完整生成与继续编辑

依赖：Node、Python 3、现有 `playwright-core` 和 Chromium。CLI 不需要 GPT Key、FrameRonin Key 或 Unity。脚本优先使用当前电脑已有的 `clawdbot/node_modules`，不会安装或修改系统配置。

```powershell
& 'C:\Gamedev\Unity\Project\FantasyWord\artifacts\ronintile-workflow-replica-20261030\deliverable\replay.ps1' -Output 'C:\Gamedev\Unity\Project\FantasyWord\artifacts\my-ronintile-replay'
```

`input/world-recipe.json` 是已执行的 866 步生成配方；`input/final-edit-template.json` 是已执行的 7 步原生继续编辑：移动旅馆招牌、保存重读、重新导出。两段均保留原版 API 的实际执行报告。`replay.ps1` 按这个顺序重放，不覆盖已有目录。

单独编辑已保存工程的例子：

```powershell
$env:NODE_PATH='C:\Users\zhuagenbao\AppData\Roaming\npm\node_modules\clawdbot\node_modules'
$p='C:\Gamedev\Unity\Project\FantasyWord\artifacts\ronintile-workflow-replica-20261030\deliverable'
node "$p\toolkit\ronintile_cli.mjs" --recipe "$p\examples\edit.json" --output 'C:\Gamedev\Unity\Project\FantasyWord\artifacts\my-ronintile-edit' --engine "$p\engine" --quiet true
```

例子从真实原生工程读入，擦除地面一格，撤销、恢复、再撤销回原状，保存重读后重新输出 JSON/PNG。修改配方里的 `draw/paint/stamp/layer/prop/relation` 等步骤即可编排新地图。`call` 只允许调用原引擎已导出函数，参数为 JSON 和显式图块/源引用，不执行输入脚本。

原工程内重新准备素材或生成 Tiled/连续室内预览：

```powershell
cd 'C:\Gamedev\Unity\Project\FantasyWord'
python -X utf8 scripts/ai-map-experiment/ronintile_world.py prepare --output artifacts/my-source
node scripts/ai-map-experiment/ronintile_cli.mjs --recipe artifacts/my-source/world-recipe.json --output artifacts/my-native --quiet true
python -X utf8 scripts/ai-map-experiment/ronintile_world.py export --input artifacts/my-native --assets-source artifacts/my-source --output artifacts/my-map --verify --node-modules C:/Users/zhuagenbao/AppData/Roaming/npm/node_modules/clawdbot/node_modules
```

此作者准备/预览转换依赖当前工程的原素材、原示例场景和已保留的 Forge 导航工具；解包后可独立使用的是原生 CLI、已内嵌素材的工程/配方、Tiled 地图和 HTML 预览。CLI 所有输出目录必须全新。

## 已验收证据与边界

`evidence/workflow-verification.json`：Blob/Wang 各 14 类实际导出；图集重建、原生 Image 导出与渲染对账；关系回读；撤销 776→768、恢复 768→776；Unity 归档可解开、内部 GUID 一致。

`map/native-consumption-report.json`：10,792 个放置逐格对原生工程/图集检查；原始 PNG/Meta 未变化；全部放置引用原素材。Canvas 编解码最大通道差为 1/255。

`map/tiled-verification.json`：Tiled 1.12.2 实际重读 TMX、TMJ，两者 148 层，重绘与原生渲染最大通道差均为 1/255。

`map/bundle-validation.json`、`map/nav-check/nav-report.json`：数据零错误、零警告，20 个门内外目标全部可达。

`map/preview/preview-qa.json`：真实浏览器键盘/点击，并连续步进逐栋完成 10 栋进出、屋顶隐藏/恢复、墙和家具碰撞；没有重置角色来伪造到达，没有地图切换、页面跳转或外部请求。

准确边界：七类导出没有分别在 Unity/Godot/GameMaker/Defold 中运行；等距、旧工程迁移、79 个 API 的所有组合、完整 GUI 操作没有全部验收。本地原 UI 仍缺少部分图标和默认占位资源；已验收的 CLI 全部显式绑定实际素材，最终放置无占位引用。不能把本包说成“全站完整重写”或“Unity 游戏已完成”。

原网页文件宿主发现两处与原导出模板不匹配：GUID 缺 `create().value`、归档仅拼文本。`ronintile_host.mjs` 补齐这两项调用合同，Python 真正生成 tar.gz。原业务源码/模板文件未改。CLI 还等待边界测宽与图像缓存稳定，避免异步刷新前截图。
