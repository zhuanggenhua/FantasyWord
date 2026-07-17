# 0057-主玩家控制目标必需配置参考流程边界

- 日期：2026-07-16
- 状态：已采纳
- 背景：
  - 2DRPGEngine 的同职责流程是 `PlayerSystem` 创建正式玩家 `Hero`，`Movable` 通过序列化的 `IController` 启停玩家控制器；玩家控制器是正式玩家闭包的一部分，不是可有可无的表现层附件。
  - FantasyWord 为了支持预摆主角、当前受控角色和控制组，把输入落点从参考工程的单个 `PlayerController` 扩展为 `IPlayerInputTarget`，当前默认由角色上的 `CharacterPlayerControl` 提供。
  - 这项扩展是当前项目的必要适配，但主玩家缺少 `CharacterPlayerControl`、组件被禁用或不接收玩家输入时，启动和读档不应静默进入“等待恢复”状态；那是场景/Prefab 配置错误，不是跨地图或死亡态恢复。
- 决策：
  - 保留 `PlayerSystem` 作为玩家实体、当前受控目标和控制组的正式 owner。
  - 保留 `CharacterBase.TryResolvePlayerInputTarget(...)` 的运行态可失败语义：角色死亡、变身/感染导致玩家控制锁定、控制组件临时不可用时，玩家控制可以等待恢复或回退。
  - 新增 `CharacterBase.HasConfiguredPlayerInputTarget(...)`，只表达配置合同：角色是否有启用的 `CharacterPlayerControl` 且该组件接收玩家输入。
  - `PlayerSystem.OnSystemStart()` 和 `PlayerSystem.LoadDataBlock(...)` 必须先验证主玩家具备上述配置合同；缺失时抛出可定位异常，不能吞成空输入目标。
  - 不把这项决策解释为“所有控制切换失败都要抛异常”。手动选择不可控角色、控制组成员过滤、读档恢复到未加载/已失效角色，仍可按当前项目语义返回 false、过滤或等待恢复。
- 影响：
  - 主玩家 Prefab/场景配置缺失会在玩家系统启动或读档时直接暴露。
  - 死亡、控制锁定、跨地图引用暂不可解析等运行态失败仍保持原有可恢复流程。
  - Foundation 静态门禁新增主玩家输入目标配置合同检查，但不新增任何 `TryGetSystem` 或禁止 `GameManager.XxxSystem` 的访问形式规则。
- 替代关系：
  - 本决策补充 0049 和 0050：继续按参考同职责流程判断失败语义；本项只针对主玩家控制目标配置，不改变 GameManager 系统访问边界。
