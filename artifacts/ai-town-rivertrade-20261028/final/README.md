# 河渡贸易镇：Tiled 室外实验

采用现有 MiniFantasy Towns I / Forgotten Plains 素材；原版 Tiled 1.12.2 实际执行 Automapping、保存 TMX/TMJ 和原生渲染。
设计：桥头 → 市场棚亭和水井 → 北侧商旅街；南侧转入庭院、住宅支巷，经南桥返回西岸。西岸旧石塔与仓库构成独立短线。

## 查看和编辑

- `town-overview.png`：原生地图渲染的2倍最近邻放大，640×480逻辑像素，80×60格。
- 用 Tiled 打开 `river-trade-town.tmx` 或 `river-trade-town.tiled-project`；贴图和 TSX 全部采用包内相对路径。
- `preview/preview.html`：双击打开离线预览，按页面说明移动；角色是验证标记。
- `规划输入`、`水域输入` 是隐藏的概念层；`town-rules.tmj` 是由原包固定朝向规则转换的原生自动铺图规则。
- `建筑入口与探索点`、`碰撞规划` 是隐藏设计对象层；用途、门口、源 GUID/fileID 保留为属性。

## 当前验证

- 10栋建筑逐格对照原示例组合；实际门口对准原门瓦片。
- 离线14个互动目标全部可达；浏览器独立路线和排序检查通过，0警告。
- 下列3条路线在实际碰撞网格上只沿已铺街道通过，不借草地绕过断路：
- 初次到镇：816px，约25.5秒纯步行。
- 市场到住宅再回桥头：1324px，约41.4秒纯步行。
- 西岸探索线：572px，约17.9秒纯步行。
- 两座桥分别关闭时另一座仍连通；同时关闭会隔断两岸，证明双桥构成真实回路。
- 原素材 SHA256 回读一致。以上验证是作者工具和离线地图层验证，未启动 Unity。

## 导入 Unity 的下一步

可以用 SuperTiled2Unity 导入 TMX：https://github.com/Seanba/SuperTiled2Unity 。
将地图和整个 assets 目录一起放入 Unity 后，可由导入器创建 Tilemap。此包使用派生图集；属性中的原始 GUID/fileID 用于追溯，不会自动变回原包 RuleTile 或 Prefab。
本轮未安装导入器，未验证本工程 Unity/URP 2D 的兼容性、像素采样、排序和碰撞。隐藏设计层应由正式导入适配器明确处理，不能直接当作已接入游戏的门、NPC、交易或任务。
建筑目前采用整块占地阻挡。室内、屋顶遮挡、精确碰撞和门的场景切换仍需后续工作。

## 在当前工作区复现

从工程根目录运行（新输出目录不可已存在；不打开 Unity）：

```powershell
python -X utf8 scripts/ai-map-experiment/generate_town.py --output-dir artifacts/ai-town-rivertrade-rerun --check --node-modules C:/Users/zhuagenbao/AppData/Roaming/npm/node_modules/clawdbot/node_modules
python -X utf8 scripts/ai-map-experiment/review_town.py --output-dir artifacts/ai-town-rivertrade-rerun
```

本机 Tiled 缓存：`Temp/tiled-1.12.2/app/tiled.exe`；原版 MSI 下载地址和 SHA256 记录在同级 `source.json`。Python 依赖 Pillow、PyYAML、NumPy。
原生 Automapping 需要编辑器文档，纯 `--evaluate` 对分离地图不支持此操作。因此生成脚本通过 CLI 启动隐藏 Tiled 进程，在本任务便携副本内加载扩展，输出后自动退出；不用鼠标铺图。
规则选择第一静态帧，未接入原包动画；地图不包含 AI 绘制或替代素材。
素材仅用于当前已授权的本地工程实验，不应把含有商业素材的 ZIP 公开分发。
