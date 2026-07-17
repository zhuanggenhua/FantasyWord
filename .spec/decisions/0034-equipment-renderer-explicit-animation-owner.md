# 0034-EquipmentRenderer 显式动画依赖 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `EquipmentRenderer` 是换装 Shader、装备层和逐帧帧数据同步的表现 owner，不应再自行猜测角色动作依赖。
  - 旧实现会从父级查找 `AnimationController`，再扫描子级 `Animator`，并用 UI 对象名排除候选。
  - 这和 `AnimationController` 旧问题同源：层级一复杂，渲染器可能绑定到错误 Animator 或把 UI/气泡等表现节点纳入正式动画判断。
- 决策：
  - `EquipmentRenderer` 必须暴露显式 `animationController` 和 `characterAnimator` 引用。
  - 正式基础角色 Prefab 必须绑定 `EquipmentRenderer.animationController` 和 `EquipmentRenderer.characterAnimator`。
  - 为兼容未保存场景，运行时只允许同对象 `AnimationController`、动作控制器暴露的 Animator 或同对象 Animator 作为组合期缓存；不得向父级或子级搜索。
  - 保留装备贴图校验中的名称判断；该逻辑只判断 Sprite/Texture 是否像 UI 图标或整帧角色图，不承担依赖查找。
  - 换装静态门禁必须覆盖父级动作控制器查找、子级 Animator 扫描、按 UI 名称过滤候选和基础 Prefab 显式绑定。
- 影响：
  - 换装渲染器继续只负责表现同步，不拥有动作状态或方向 SpriteLibrary。
  - 基础角色 Prefab 中渲染器的动作依赖变为可审计序列化引用。
  - 本决策不改变装备层合成、Shader 参数、武器锚点或工作台预览刷新策略。
- 替代关系：
  - 补强 `0033-AnimationController 显式依赖 owner 边界`：动作控制器显式化后，消费它的换装渲染器也必须显式接入，而不是重新扫描层级。
