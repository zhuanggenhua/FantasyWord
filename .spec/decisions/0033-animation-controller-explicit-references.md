# 0033-AnimationController 显式依赖 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `AnimationController` 是换装角色动作播放的正式入口，只应决定和播放动作状态。
  - 旧实现会扫描同对象和子级 `Animator`，再用 UI 对象名排除候选；脚底阴影也通过 `transform.Find("Shadow")` 查找。
  - 基础角色 Prefab 的真实阴影对象叫 `Blob Shadow`，旧硬编码名字不能稳定命中，且子级扫描会让动画控制器在层级复杂后错误绑定 UI 或表现子对象。
- 决策：
  - `AnimationController` 必须暴露显式 `characterAnimator` 和 `shadowObject` 引用。
  - 正式基础角色 Prefab 必须绑定 `characterAnimator` 和 `shadowObject`。
  - 为兼容当前未保存的 Demo 场景，运行时只允许同对象 `Animator` 作为组合期缓存兜底；不得跨子级扫描、不得按 UI 名称过滤候选。
  - 脚底阴影为空表示该角色没有由动作控制器管理的独立阴影；不得再按子物体名搜索。
  - 换装静态门禁必须覆盖子级 Animator 扫描、UI 名称排除、`Shadow` 硬编码查找和基础 Prefab 显式绑定。
- 影响：
  - 基础角色 Prefab 的动作 Animator 和阴影对象 owner 变为序列化引用，运行时不再猜测。
  - 当前用户正在编辑的场景不被加载或保存；已有同对象 Animator 的 Demo 对象仍可通过同对象缓存运行，但不作为正式 Prefab 接线标准。
  - 本决策不改变动作状态、方向 SpriteLibrary 变体、换装 Shader 或工作台预览刷新语义。
- 替代关系：
  - 补强 `0020-换装表现桥接显式渲染器 owner 边界`：换装表现桥接显式绑定渲染器后，动作控制器也必须显式绑定自己的 Animator 和阴影依赖。
