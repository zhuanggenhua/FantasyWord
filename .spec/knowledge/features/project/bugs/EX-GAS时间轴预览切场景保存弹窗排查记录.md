---
name: EX-GAS时间轴预览切场景保存弹窗排查记录
description: 项目知识：bugs/EX-GAS时间轴预览切场景保存弹窗排查记录.md：EX-GAS时间轴预览切场景保存弹窗排查记录。
metadata:
  type: doc
  status: 已交付
---

# EX-GAS 时间轴预览切场景保存弹窗排查记录

## 症状

- 打开或返回 EX-GAS 时间轴预览场景时，Unity 可能弹出保存确认框。
- 自动化流程会因此卡住，人工流程也会被迫判断“是否保存预览场景”。

## 误判风险

- 不能把“当前没有弹窗”当成根因已解决；必须检查打开预览场景和返回原场景两个方向。
- 不能只在 `LoadPreviewScene()` 前保存正式场景，却让 `BackToScene()` 从预览场景返回时直接 `OpenScene(..., Single)`。
- 不能把所有 Unity 写操作都扩大成全局自动保存；这里只修 EX-GAS 时间轴编辑器的场景切换入口。

## 真实根因

- EX-GAS 时间轴编辑器会用 `EditorSceneManager.NewScene(..., Single)` 创建预览场景。
- 返回原场景时，如果当前预览场景已经 dirty，直接 `EditorSceneManager.OpenScene(..., Single)` 仍可能触发保存确认框。
- 旧实现只在打开预览场景前做保存守卫，返回原场景的预览分支没有同样的守卫。

## 修复点

- `Assets/Plugins/GAS/Editor/Ability/AbilityTimelineEditor/EditorWindow/AbilityTimelineEditorWindow.cs`
  - `BackToScene()` 在任何 `OpenScene(..., Single)` 前统一调用 `SaveDirtyOpenScenesBeforeSwitch()`。
  - 保存失败时停止切场景，并输出明确错误，避免继续触发 Unity 保存弹窗。

## 必查项

- 打开预览场景前是否先处理 dirty 场景。
- 从预览场景返回原场景前是否同样处理 dirty 场景。
- 修复后不得新增项目侧第二套时间轴、工作台、准备链路或修复接线。
- 场景切换修复后必须复查当前正式场景是否仍为 `isDirty = false`。

## 验收口径

- Unity `assets-refresh` 必须通过，证明编辑器代码能编译。
- 基础攻击相关 EditMode 回归必须通过，证明 EX-GAS Timeline 运行链没有被破坏。
- `scene-list-opened` 必须显示当前正式场景 `isDirty = false`。
