# Proposal: formalize-equipment-visual-workbench

## Why

当前换装系统已从一次性功能测试推进到正式生产模块的重构阶段。用户已经明确要求：

- 测试代码和测试夹具不能继续作为正式实现。
- 角色选择、动作切换、方向切换、装备选择需要可用的网格测试 UI。
- 角色和装备格子应显示可识别的首帧/图标，而不是只有文字。
- 左侧应是角色/动作/方向等控制，右侧应是装备类型与装备网格，中央预览不能被 UI 挡住。
- 数据目录必须区分装备规则数据与表现层资源，例如装备数据归 `EquipmentSystem/Data`，表现层资源归 `Equip/Visual` 或等价正式边界。
- 正式项目侧资产优先中文命名，但运行时稳定 ID、代码符号和兼容键可以保留 ASCII。
- AIBridge 需要稳定支持端到端验证，不能出现“Unity 已执行但外层超时/残锁/scene-open 状态不一致”的假失败。

## What Changes

- 将 `EquipmentSystemDemo` 从临时测试入口收口为正式的换装工作台/预览 smoke 场景。
- 明确装备数据由“规则属性 + 表现资源”组成，规则数据和表现资源分层存放。
- 明确运行时 UI 的结构：左侧角色、动作、方向；中间预览；右侧装备类型和装备网格。
- 明确格子显示要求：角色格子显示角色 idle 首帧，装备格子显示装备表现首帧或 icon，并高亮当前选择。
- 明确表现层不直接伪造装备规则；没有物品系统完整闭包时，工作台可以读取正式装备候选数据，但不得把字符串测试项伪装成正式 GAS/物品系统。
- 修复并加固 AIBridge 文件 IPC，使端到端验证可以作为当前 change 的可信证据来源。

## Scope

本 change 只覆盖换装表现工作台、装备表现数据边界、最小装备候选数据和验证工具稳定性。

不覆盖完整物品背包、装备穿戴规则、GAS 属性替换、玩家控制器对接、存档、掉落、商店或正式 HUD。

## Current Evidence

- 已改动 AIBridge CLI：`.codex/skills/aibridge/bridge.py`，加固结果文件读取、超时边界复查和死锁清理。
- 已改动 AIBridge Unity 包：`Packages/com.aibridge.unity/Editor/Tools/Scene.Open.cs`，让 `scene-open` 打开场景后尝试设为 active，并避免把 Unity active-scene 延迟回报误判为场景未打开。
- 已观察到 `scene-open` 曾实际打开 `Assets/Scenes/EquipmentSystemDemo.unity`，脚本回读 active scene 为 `EquipmentSystemDemo`；但 `scene-open` 外层仍曾返回 error，原因是包侧返回层对 `SetActiveScene` 的 false 结果处理过严。
- 最新包侧改动已将该 false 结果降级为 warning，但尚未完成重新验证，因为上一会话被中断。

## Risks

- Unity Editor 重载、场景恢复弹窗或多 Unity 进程会让 `Temp/UnityBridge/heartbeat` 指向旧进程，导致 Bridge 假死。
- UPM 包内 C# 改动有时需要 `assets-refresh` 和 domain reload 后才会被当前 Editor 装载。
- 当前工作区很脏，存在大量与本 change 无关的迁移/素材/归档变动；不得为了收口换装系统而回滚或清理这些无关变动。

