# ClickMoveTest 训练假人角色切片

## 前提与边界

对象为原项目提交 `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的 ClickMoveTest 活跃训练假人实例 `735002000000000003`，不是旁边禁用的转向测试实例。本切片迁移真实的受击盒、身体和伤害回调接线，不安装半套 AI，也不声称视觉、存档、完整 GAS 生命周期完成。

源链为 `测试-训练假人.prefab → 0_CharacterActor_Base.prefab → 0_Character_Base.prefab`。场景坐标是 (2.5, -2.75)；基础身体为垂直胶囊，尺寸 (.78, .86)，中心 (0, .42)；独立受击触发盒为 (.6, 1)，中心 (0, .5)，Unity 层 7；基础角色对根对象另有 m_Layer=8 覆盖，身体使用 Character 位 256。迁移时仅转换 y 轴方向，保留原单位，不用诊断场景的一格矩形替代。场景、变体和基础 Actor 均无覆盖这些形状的修改。

角色配置的九项整数依照 `Stats.cs / EStat` 顺序为生命 220、法力 0、物攻 0、魔攻 0、物防 0、魔防 0、敏捷 0、幸运 0、攻速 100；阵营是 Evil。最后一项不得当成未配置零值。原角色有 20001 技能和 AI，故本切片不默认启用一个静止假人来冒充完整 NPC。

## 拥有者接口

`training_target.gd` 必须先 `configure(bindings, movement_owner, terrain_mask)` 再加入树。配置缺失返回 false，进入树前缺失配置直接报错。

- 属性只读入口 `stats()`、`current_health()`、`has_formal_stats()`；
- 唯一写入口 `apply_current_health_delta(delta, minimum, maximum, source)`；
- 明确的 `impact`、`provoke`、`prepare`、`complete`；
- 安全阶段回调 `is_destroyed`、`interrupt_actions`、`mark_death`；
- 动作拥有者遵守现有 NativeMotionBody 接口；不自动查找场景角色或创建属性存储。

`hooks()` 复用现有伤害提交管线。仅将 prepare 和成功的属性写入通知交给既有延迟打断/死亡组件；真实属性由外部唯一拥有者提供。没有第二套生命值镜像。impact 原样委托，避免效果桥和角色各自再推一次。安全阶段与固定物理阶段须由组合入口显式推进，不能另开重复调度。训练假人的身体继承既有源运动与推力适配，当前不补齐 AI、传送、墙内恢复或真实素材表现。

## 验证

`tests/test_training_target.gd` 定向 18/18：源坐标和继承形状、原生物理点查命中/排除、单一属性写入、非致死打断、生命归零后的延迟死亡及去重。测试中的外部属性拥有者仅为明确测试夹具，生产实现不依赖 validation 目录。本结果不是正式原场景的运行截图或完整 NPC 验收。

地形 mask 由入口注入；只有该 mask 含 Character 位才能验证角色互相阻挡。本切片不将命中盒通过等同于完整移动碰撞通过。

## 显式受击入口组合

`start_training_damage_target` 将锁定角色表、唯一受击属性拥有者和真实身体绑定到当前 Entry。仍需显式注入动作、受伤和安全阶段拥有者；不在场景资源中默认添加静止的假人来冒充完整 NPC。`training_damage_attributes.gd` 迁移无活动修饰的受伤分支：按正式角色表初始化生命与其独立上限；瞬时加法作用于生命属性的 BaseValue，再重算当前值；当增量被钳制为 0 时不发出变更。这里不含法力写入、治疗、叠层、完整 ASC 或存档。死亡和无敌标志仍由角色生命周期拥有，不通过备用生命字段猜测。

`start_human_charged_training_combat` 接通同一个 Entry 中的实际玩家与假人。20004 不默认装备；命中只认假人的真实受击盒，不用测试场景碰撞或创建替代目标。第 12 帧采样玩家和假人当前根坐标，执行 [2004 伤害阶段](charged-damage-phase.md)。根据锁定 `Assets/GameData/GameCore/GameConfig.asset` 启用暴击和闪避，并通过受击身体唯一提交默认推力；普通、暴击、闪避分支允许推力，静默分支不开启。测试中的抽样是显式固定序列，不宣称与原引擎抽样序列相同。

组合验证 `test_clickmovetest_training_damage.gd` 同时核对源出生点、生命 220、显式蓄力输入、帧 12 后生命 198、独立上限不变、真实物理推进、延迟打断和收招不重复扣血。测试会为命中故意放置玩家到范围内，不等于玩家自然移至此处或 AI 已能自行选敌。允许私有锁定原图集和原导航数据作为实际输入；公共版使用隔离切片夹具，并非正式素材。无游戏图形、双端截图、效果事件销毁、受击动画、CueOnApply 20001、自然 AI 和整场交付之验收结论。
