# 野外地图 CLI 实验：林间遗迹与湖湾

本轮交付位于 `final/`。实验使用用户截图确定素材语言，由当前 AI 助手编写布局规划，Python CLI 读取已有 MiniFantasy 切片和示例组合生成地图。美术来源为 `existing`，没有调用图片生成模型，没有启动 Unity，也没有向 `Assets` 写入资源。

## 查看结果

- `final/map-preview.png`：完整离线预览，1152 × 960；原生像素尺寸为 384 × 320，采用三倍最近邻缩放。
- `final/preview/preview.html`：自包含浏览器走图预览。方向键或 WASD 移动，点击寻路；角色是预览工具的调试标记。
- `final/tiled/map.tmj`：可编辑 Tiled 地图，包含原素材派生图集、图层、物体、碰撞和目标点。
- `final/layout.json`：本轮布局输入快照；原始可修改输入位于 `scripts/ai-map-experiment/layout-forest-ruins.json`。
- `final/source-audit.json`：原始文件哈希、Unity Sprite 的 GUID/fileID、切片矩形和示例组合来源。
- `reference/user-reference.png`：本轮用户提供的参考截图。

## 已验证的结果

| 项目 | 结果 | 直接证据 |
| --- | --- | --- |
| 地图结构和资源引用 | 通过，0 错误、0 警告 | `final/bundle-report.json` |
| 出生点和三个目标的可达性 | 3/3 可达 | `final/nav/nav-report.json` |
| 浏览器资源加载 | 27/27 加载成功 | `final/preview/preview-qa.json` |
| 浏览器键盘移动、三条路线和前后遮挡 | 通过，严格模式 0 警告 | `final/preview/scene-snapshot.json`、`final/preview/preview-qa.json` |
| Tiled 数据回读与原地图渲染的一致性 | 两种导出均为 0 差异像素 | `final/tiled/export-report.json` |
| 相同布局和种子的两次新生成 | 地图数据、原生图与放大图的哈希一致 | `final/determinism-report.json` |
| AI 对离线画面的检查 | 符合首轮实验口径 | `final/visual-review.json` |

## 如何复现

从工程根目录执行以下单条命令；输出目录必须是新目录。当前机器已有 Pillow、numpy、PyYAML 和 Playwright Core。生成器会按 `forge-cli-lock.json` 下载并校验缺失的参考工具，缓存放入 `Temp/ai-map-forge`。

```powershell
python -X utf8 scripts/ai-map-experiment/generate_outdoor.py --output-dir artifacts/ai-map-outdoor-next --check --node-modules C:/Users/zhuagenbao/AppData/Roaming/npm/node_modules/clawdbot/node_modules
```

调整布局 JSON 中的湖面多边形、道路、示例组合位置、目标点和种子后，可用同一命令生成其他布局。当前实现支持的范围是 Forgotten Plains 野外素材实验，不是通用房屋、城镇或室内生成器。

## 参考的采用方式

- Sprite2World：借鉴 AI 生成语义规划、代码完成确定性拼装和校验的职责划分；本轮没有运行或整包接入该应用。
- agent-sprite-forge 的 `generate2dmap`：实际使用原版地图结构检查、寻路检查、浏览器验证和 Tiled 导出 CLI。已锁定提交 `5324342fdfab72430f4e9604f3fe427009f8596d`，参考代码未修改。
- 当前项目的 InteliMap Pro：依赖 Unity 环境；本轮按用户“现在不需要打开 Unity”的要求，保留为后续 Unity 接入的候选，不声明已经训练或启用。
- MiniFantasy：读取原包切片与标准 Tile 示例的组合；不修改第三方图片、场景、Prefab 或导入设置。

## 验收边界

本轮证明的是离线地图生成、可编辑数据导出和浏览器预览流程。未验证 Unity 导入、编译、GameView、正式角色移动或物理碰撞；Tiled GUI 也未打开验证。水面只使用静态帧，高台只验证地面绕行，不包含高度导航。碰撞取自本实验明确编写的地面阻挡和树干范围，不能代替原游戏的实际碰撞验收。

同级 `generated*` 目录保存先前迭代证据，交付与结果声明以 `final/` 为准。
