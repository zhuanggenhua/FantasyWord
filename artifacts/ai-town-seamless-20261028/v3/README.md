# 河渡贸易镇：同图室内外连续空间

采用现有 MiniFantasy Towns I / Forgotten Plains 素材；原版 Tiled 1.12.2 实际执行 Automapping、保存 TMX/TMJ 和原生渲染。
设计：桥头 → 市场棚亭和水井 → 北侧商旅街；南侧转入庭院、住宅支巷，经南桥返回西岸。西岸旧石塔与仓库构成独立短线。

## 查看和编辑

- `town-overview.png`：原生地图渲染的2倍最近邻放大，640×480逻辑像素，80×60格。
- 用 Tiled 打开 `river-trade-town.tmx` 或 `river-trade-town.tiled-project`；贴图和 TSX 全部采用包内相对路径。
- `town-interiors.png`：同一张地图临时揭开所有建筑遮挡后的原生作者检查图，不是另一张室内地图。
- `preview/preview.html`：双击打开，WASD/方向键移动、点击寻路、滚轮缩放、M总览。角色采用原包静态帧。
- 从门洞直接走进原地房间，只揭开本栋屋顶和遮挡立面；离开恢复，世界坐标和地图均不切换。
- `规划输入`、`水域输入` 是隐藏的概念层；`town-rules.tmj` 是由原包固定朝向规则转换的原生自动铺图规则。
- 每栋建筑是原生 Tiled 分组，内部包含室内地板、室内墙体、室内家具、外观叠层、屋顶、墙体碰撞、空间与入口。
- 整栋移动：选择建筑组，修改组偏移（像素，建议8的整数倍）；所有子层、家具、入口、室内区域和碰撞一起移动。
- 看室内：隐藏组内 renderRole=cover 的外观/屋顶/阴影子层。运行时按室内区域自动执行，无需手动切层。
- 改墙、门洞或家具时，同时检查本栋的墙体碰撞和家具 footprint 属性。隐藏屋顶不改变任何碰撞。
- `建筑入口与探索点`、`碰撞规划` 是城镇公共设计层；各栋门洞和室内行走点位于自己的组内。
- 当前浏览器预览是本次导出的快照，Tiled 手动保存不会自动刷新；保留手改TMX，不要用从布局重建的命令覆盖它。

## 当前验证

- 10栋建筑使用原示例外观瓦片，打开原门瓦片位置的真实通道，室内采用原包地板、墙和家具。
- 离线24个室内/外目标全部可达；浏览器逐栋实际行走进出，验证屋顶隐藏/恢复、后墙和家具碰撞。
- 浏览器检查每个移动步长不超过预算，地图ID和内容哈希始终相同，传送入口、页面导航和外部请求均为0。
- 下列3条路线在实际碰撞网格上只沿已铺街道通过，不借草地绕过断路：
- 初次到镇：816px，约25.5秒纯步行。
- 市场到住宅再回桥头：1324px，约41.4秒纯步行。
- 西岸探索线：620px，约19.4秒纯步行。
- 两座桥分别关闭时另一座仍连通；同时关闭会隔断两岸，证明双桥构成真实回路。
- 原素材 SHA256 回读一致。以上验证是作者工具和离线地图层验证，未启动 Unity。

## 导入 Unity 的下一步

可以用 SuperTiled2Unity 导入 TMX：https://github.com/Seanba/SuperTiled2Unity 。
将地图和整个 assets 目录一起放入 Unity 后，可由导入器创建 Tilemap。此包使用派生图集；属性中的原始 GUID/fileID 用于追溯，不会自动变回原包 RuleTile 或 Prefab。
本轮未安装导入器，未验证本工程 Unity/URP 2D 的兼容性、像素采样、排序和碰撞。自动揭顶在浏览器预览中实现，导入Unity后还需由正式表现组件消费同一建筑组和室内区域；不能称为Unity功能已接入。
仅地面层；多楼层、NPC、交易、任务和大世界流式加载不在本轮范围。室内外连通不需要场景切换。

## 在当前工作区复现

从工程根目录运行（新输出目录不可已存在；不打开 Unity）：

```powershell
python -X utf8 scripts/ai-map-experiment/generate_town.py --output-dir artifacts/ai-town-seamless-rerun --check --node-modules C:/Users/zhuagenbao/AppData/Roaming/npm/node_modules/clawdbot/node_modules
python -X utf8 scripts/ai-map-experiment/review_town.py --output-dir artifacts/ai-town-seamless-rerun
```

本机 Tiled 缓存：`Temp/tiled-1.12.2/app/tiled.exe`；原版 MSI 下载地址和 SHA256 记录在同级 `source.json`。Python 依赖 Pillow、PyYAML、NumPy。
原生 Automapping 需要编辑器文档，纯 `--evaluate` 对分离地图不支持此操作。因此生成脚本通过 CLI 启动隐藏 Tiled 进程，在本任务便携副本内加载扩展，输出后自动退出；不用鼠标铺图。
规则选择第一静态帧，未接入原包动画；地图不包含 AI 绘制或替代素材。
素材仅用于当前已授权的本地工程实验，不应把含有商业素材的 ZIP 公开分发。
