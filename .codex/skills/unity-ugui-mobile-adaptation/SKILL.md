---
name: unity-ugui-mobile-adaptation
description: Unity UGUI mobile layout adaptation and review focused on RectTransform anchors, pivot, offsets, Canvas Scaler, safe area, aspect ratio, LayoutGroup, ContentSizeFitter, ScrollRect, and notch-safe full-screen behavior. Use when Codex modifies, reviews, or debugs Unity UGUI layouts for mobile devices, especially when changing anchors, panel alignment, adaptive sizing, edge pinning, top/bottom bars, full-screen overlays, or screen-fit behavior. 适用于修改或排查 Unity UGUI 移动端适配、锚点、边距、全屏拉伸、Canvas Scaler、安全区、布局组、滚动列表和分辨率适配问题。
---

# Unity UGUI Mobile Adaptation

## 概述

处理 Unity UGUI 移动端适配时，先把问题收口到正式布局真相：`RectTransform`、`CanvasScaler`、安全区、父级约束和布局组件边界。  
目标不是“编辑器里看起来差不多”，而是在不同分辨率、横竖屏比例、刘海屏和异形屏下都保持可预期的布局行为。

## 工作方式

1. 先确认当前任务确实是 UGUI，而不是 UI Toolkit 或纯美术资源问题。
2. 先读 `references/ugui-mobile-checklist.md`，按检查顺序核对当前布局。
3. 先修正式锚点、父级约束和 `CanvasScaler`，不要先加运行时补丁。
4. 只有当静态布局无法承载设备差异时，才进入安全区脚本或运行时尺寸适配。

## 非协商规则

- 不要把锚点错误、父级尺寸错误或 `LayoutGroup` 冲突伪装成“加一段运行时代码就好了”。
- 不要在同一语义上同时依赖锚点拉伸、手写 `sizeDelta`、布局组件驱动和脚本强改位置。
- 不要为了局部修正去破坏其他已完成面板的正式层级或共享骨架。
- 不要默认使用固定像素坐标思维处理移动端 UGUI；优先用锚点、边距、布局和安全区。
- 不要忽略父级 `RectTransform`。子节点锚点正确但父级边界错误，结果仍然是错的。
- 不要在 `ContentSizeFitter`、`LayoutGroup`、手动尺寸设置之间制造双向驱动。

## 优先排查顺序

1. `Canvas` 与 `CanvasScaler`
2. 父级 `RectTransform`
3. 目标节点锚点、`pivot`、`anchoredPosition`、`sizeDelta`、`offsetMin/offsetMax`
4. `LayoutGroup`、`ContentSizeFitter`、`AspectRatioFitter`、`ScrollRect`
5. 安全区与异形屏
6. 运行时脚本是否又把布局改坏

## 常见任务的默认判断

- 顶栏、底栏、角标、关闭按钮、货币栏、状态条：
  优先检查是否应该固定到父级边缘，并确认锚点是否贴边而不是靠 `anchoredPosition` 硬摆。
- 全屏弹窗、遮罩、背景板：
  优先检查是否应该四边拉伸到父级，确认 `stretch` 锚点与边距是否正确。
- 列表、背包、滚动区域：
  先看 `ScrollRect` 视口、内容根节点、`LayoutGroup` 与 `ContentSizeFitter` 是否形成冲突。
- 需要跟随机型变化的留白：
  先区分这是不是安全区问题；若是，优先把安全区作为唯一正式入口。
- 文本或按钮在小屏溢出：
  先核对父级约束、布局优先级、最小首选尺寸和文本自动换行，不要先缩放整个面板。

## 输出要求

- 说明问题属于哪一层：`CanvasScaler`、父级边界、子节点锚点、布局组件冲突，还是安全区。
- 明确给出最正确修法，而不是同时列多个同级补丁。
- 如果需要改运行时代码，先说明为什么静态 UGUI 布局不足以解决。
- 汇报时写清楚修改会影响哪些分辨率或设备边界；若未做真机验证，要明确说明。

## 参考文件

- `references/ugui-mobile-checklist.md`
  需要实际排查或修布局时先读这份清单；它定义了逐项核对顺序、典型错误模式和修法边界。
