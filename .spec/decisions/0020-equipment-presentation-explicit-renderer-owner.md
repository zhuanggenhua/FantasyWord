# 0020-换装表现桥接显式渲染器 owner 边界

- 日期：2026-07-15
- 状态：已采纳
- 背景：
  - `CharacterEquipmentPresentation` 是玩法装备状态到换装表现层的唯一正式桥接。
  - `CharacterEquipment` 是同对象必需组件，可以通过 `RequireComponent` 和 `GetComponent<CharacterEquipment>()` 作为组合期依赖解析。
  - `EquipmentRenderer` 位于角色表现子层级，原先缺引用时会用 `GetComponentInChildren<EquipmentRenderer>(true)` 自动查找；层级复杂后这会把表现 owner 隐藏在运行时搜索里。
  - 当前基础角色 Prefab 已显式绑定 `CharacterEquipmentPresentation.equipmentRenderer`，换装 Demo 场景也已有显式绑定；因此不需要保留运行时子级兜底查找。
- 决策：
  - `CharacterEquipmentPresentation` 可以解析同对象的必需 `CharacterEquipment`，但不得运行时搜索子级 `EquipmentRenderer`。
  - `EquipmentRenderer` 必须由角色 Prefab 或场景组合显式绑定；缺失时由 `RefreshFromEquipment()` 的配置错误直接暴露。
  - 换装门禁必须阻止 `CharacterEquipmentPresentation` 回到 `GetComponentInChildren<EquipmentRenderer>()`，并确认基础角色 Prefab 显式绑定换装渲染器。
- 影响：
  - `CharacterEquipmentPresentation` 不再在 `Awake` / `OnEnable` 自动查找子级 `EquipmentRenderer`。
  - 基础角色 Prefab 继续使用现有显式引用，不需要迁移资源。
  - `scripts/Invoke-EquipmentSystemStaticGate.ps1` 已扩展检查换装表现桥接的显式渲染器 owner。
- 替代关系：
  - 本决策细化 `0011-换装表现资源 owner 边界`，把“运行时不按路径/层级猜资源 owner”扩展到角色换装表现桥接。
