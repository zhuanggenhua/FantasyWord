# 0028-换装工作台按钮监听 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - 换装工作台的角色槽、装备槽和筛选 chip 都会反复复用同一个按钮 View，并在 `Bind()` 时替换点击回调。
  - 旧实现用 `button.onClick.RemoveAllListeners()` 清理旧回调；这会删除同一个 Button 上由 Prefab、调试工具、可访问性组件或外部组合层添加的其它监听。
  - 项目 UI owner 决策已经要求按钮组件只注销自己注册的监听，不能清空外部 owner 的监听。
- 决策：
  - `EquipmentWorkbenchIconSlotView` 和 `EquipmentWorkbenchChipButtonView` 必须保存自己注册的 `UnityAction`。
  - 重新绑定、禁用和销毁时，只允许调用 `RemoveListener(currentClickListener)` 移除自身监听。
  - 换装静态门禁必须禁止工作台按钮 View 使用 `RemoveAllListeners()`，并检查新增监听能通过保存的 `UnityAction` 注销。
- 影响：
  - 工作台运行时复用按钮时仍能替换自己的点击行为，但不会误删 Prefab 或外部组件挂在同一按钮上的其它监听。
  - 该改动只影响工作台 UI 组件监听生命周期，不改变换装数据、资源生成器或场景绑定。
- 替代关系：
  - 本决策是 `0003-UI 菜单与按钮 owner 边界` 在换装工作台表现层的具体化。
