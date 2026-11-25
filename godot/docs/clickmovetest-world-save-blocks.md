# ClickMoveTest：原正式会话的存档字段基础

以锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的
`SaveSystem.GenerateSavefileHeader/CreateDataBlock`、`MapSystem`、
`GameFlagSystem`、`PersistenceSystem` 和 `InventorySystem` 为依据。以下是独立的内存边界，
不是整个 SaveDataBlock，不提供写盘、确认为存档、读档成功事件或 Continue。

- 标题只从原正式登记的主角生成；当前控制目标为空时仍使用主角。锁定角色配置没有单独显示名，
  GameConfig 无 level 术语，故源字符串为「玩家角色配置 [INVALID_SHORTNAME]1」。
  等级只覆盖锁定初始等级，不自行加入成长。
- 活动地图、地形导航和持久地图名不同。真实直启保留空名、空检查点栈、未设置的检查点顺序，
  不让名称查找从活动地图补一个伪持久名。读入预检分别报告缺初始检查点、具名图无法解析及
  已解析但未实现的地图过场，不发送地图事件、不提交主角位置。
- 世界标记只保存为真的原样名称。Set 即使同值也通知，内存恢复静默整体替换、去重；
  结构不受支持时保持原集合，区分已登记的空集合与没有正式会话。无暂停素材仍可采集；
  不凭空新建触发标记的场景机关。
- 原主角由 PlayerSystem 保存，活动假人明确禁用持久化，故当前正式场景的通用对象数组为空。
  运行时存在尚不能序列化的自动持久对象时拒绝，而非静默写出空结果；不持久化退出场景的弱登记。
- 只迁移登记的队伍、正式角色和尸体库存；原始物品用登记 GUID/实例解析，缺失或重复拒绝整块，
  不以名称匹配。队伍金钱按需实例化；恢复整体替换原值，不触发金钱或物品事务公告。
  原暂停 Character、Items 重新显示后读取同一所有者；之后新增加的金钱与物品各走一次原日志。
  不是旧存档容错解析，也不新增拾取、尸体操作或物品使用流程。
- 对已登记且静止、技能空闲、存活的单主角，采集当前生命、法力和原登记装备槽；完整校验后先
  应用装备，再恢复并钳制资源，未改写背包、控制或受伤流程。锁定的布衣和长矛不改变属性上限。
  实际卸装验证武器只进入背包，两个独立边界恢复后精确重采且不复制武器。非空技能状态、
  控制组、位姿、等级经验、持续效果仍不属于这一局部。
- 已发布空 Journal 使用同一正式会话生命周期：场景未成功装配或已排队删除时拒绝捕获/恢复。

使用锁定私有输入运行正常主场景相关测试：
`test_source_fresh_save_header.gd`、`test_source_map_save_capture.gd`、
`test_source_game_flags.gd`、`test_source_persistence_save_capture.gd`、
`test_source_inventory_save_capture.gd`、`test_source_player_save_slice.gd`、`test_source_journal_entry.gd`。静态命名映射夹具不等同过场或初始检查点已经实现。
实际原版磁盘档、Save/Continue UI、非空通用对象、附带任务、自定义背包及完整主角状态另行验收。
