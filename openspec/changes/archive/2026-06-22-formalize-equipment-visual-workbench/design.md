# Design: formalize-equipment-visual-workbench

## Product Boundary

换装工作台是正式生产模块的预览与内容验证入口，不是最终玩家背包 UI，也不是玩家控制器对接层。它必须能在玩家控制器尚未接入时独立展示角色、动作、方向和装备表现，但不得制造第二套装备规则真相。

## Runtime Shape

- `EquipmentWorkbenchCatalog` 是工作台可选内容目录，负责把角色、动作、方向、装备类型和装备选项组织成可浏览列表。
- `CharacterAppearance` 描述角色外观预设。
- `CharacterFrameData` 描述角色基础帧数据。
- `EquipmentRenderData` 描述装备表现资源。
- 工作台控制器负责选择状态与预览刷新。
- 工作台 UI 只负责展示与输入，不保存规则真相。

## Data Ownership

装备内容分为两层：

- 规则数据：装备的类型、属性、稳定 ID、物品/GAS 关联等，放在 `Assets/GameData/EquipmentSystem/Data` 或后续明确的 `EquipmentSystem/Data` 正式规则目录。
- 表现资源：装备的动画帧、Sprite、首帧 icon、渲染层、方向/动作映射等，放在 `Assets/GameData/EquipmentSystem/Equip/Visual` 或等价的表现层目录。

在完整物品系统和 GAS 属性专项未完成前，工作台只允许消费最小装备候选数据；不得把测试字符串、自动生成名字或 UI 内部枚举当成正式装备数据库。

## UI Layout Contract

工作台 UI 必须满足：

- 左侧：角色网格、动作切换、方向切换。
- 中央：不被常驻 UI 遮挡的角色预览。
- 右侧：装备类型切换和当前类型装备网格。
- 当前角色、动作、方向、装备类型和装备项必须有明显高亮。
- 角色格子显示角色 idle 首帧。
- 装备格子显示装备 icon；若没有独立 icon，显示装备表现资源的可识别首帧。
- 默认字体使用 `Silver`，不能退回默认字体栈。

## AIBridge Reliability Contract

AIBridge 用于本 change 的端到端 smoke。它必须满足：

- 命令已成功写出结果文件时，CLI 不应在超时边界误判失败。
- CLI 锁持有进程已退出时，后续命令应能识别 stale lock 并清理。
- `scene-open` 的成功语义必须与 Unity Editor 实际 active scene 一致；如果 Unity 已打开并激活目标场景，不应因为 `SetActiveScene` 返回 false 而把工具结果标成 error。
- Bridge 验证前必须确认 heartbeat 新鲜、无 `.cli.lock` 和 `.scene.lock` 残留、Unity `isCompiling=false` 且 `isUpdating=false`。

## Verification Strategy

默认不新增 `Assets/Tests` 测试文件。当前验收优先走：

1. 静态检查：目录、数据资产、UI/控制器代码、Bridge 改动。
2. AIBridge smoke：`editor-application-get-state`、`assets-refresh`、`scene-open`、`script-execute` 回读 active scene。
3. 工作台运行态取证：进入 `EquipmentSystemDemo` 后确认角色网格、动作网格、方向网格、装备类型网格、装备网格与当前选择状态。
4. Console：最近窗口内 Error/Exception 为空。

