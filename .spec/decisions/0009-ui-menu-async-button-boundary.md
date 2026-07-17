# 0009-UI 菜单异步按钮 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - FantasyWord 的背包、制作和商店菜单来源于 2DRPGEngine 的 UI 菜单结构，按钮点击后可能等待对话提示、物品使用、制作或交易反馈。
  - 参考工程直接在 Unity 按钮回调链上使用异步 void 方法；这会让异步异常脱离调用方，无法被菜单面板、测试或 Console 稳定归因。
  - FantasyWord 已经把菜单运行时收口到 `UIKitMenuPanelBase`，按钮事件仍必须是同步签名，但异步体不应继续留在按钮回调方法本身。
- 决策：
  - 正式 UI 运行时代码不得使用异步 void 方法承载业务流程；Unity 按钮回调只能作为同步入口。
  - 菜单面板内的异步按钮流程必须通过 `UIKitMenuPanelBase.RunPanelTaskAndReport()` 启动，由面板统一捕获并上报异常。
  - 子条目组件的公开点击回调名保持稳定；它们只调用父菜单的同步入口，不拥有异步异常处理。
  - 背包、制作、商店的规则真相仍分别由 `Item`、`CraftingStation`、`Shop` 和 `InventorySystem` 承担，菜单只负责触发和展示。
- 影响：
  - `UIKitMenuPanelBase` 新增 `RunPanelTaskAndReport()`，作为菜单按钮异步流程的唯一异常报告入口。
  - `UIInventory`、`UICraft`、`UIShop` 已把按钮点击方法改为同步入口，真实异步流程移入私有 `Task` 方法。
  - `scripts/Invoke-UIRuntimeStaticGate.ps1` 已扩展检查正式 UI 运行时代码中的异步 void 方法，并检查菜单基类存在异常报告入口。
- 替代关系：
  - 本决策保留 2DRPGEngine 的菜单职责、选中逻辑和背包/制作/交易交互形状。
  - 本决策取代参考工程中“按钮回调用异步 void 承载业务流程”的实现细节；FantasyWord 的正式 UI 入口以同步按钮回调 + 可报告 Task 为准。
