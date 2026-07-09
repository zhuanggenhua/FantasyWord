# 换装系统组织与 SpriteLibrary 评估

> 范围：`Assets/Scenes/EquipmentSystemDemo.unity`、`Assets/Scripts/Presentation/EquipmentSystem`、`Assets/GameData/EquipmentSystem` 和 MiniFantasy 原包动画组织。
> 结论时间：2026-07-06。

## 已锁定事实

| 项 | 当前事实 | 结论 |
|---|---|---|
| 脚本模块 | `Assets/Scripts/Presentation/EquipmentSystem` 只负责换装表现、UV、Shader、预览 UI、编辑器工具 | 它不是完整物品/背包/装备规则系统；`Presentation` 这一层不是多余包装，而是在表达“表现层”。 |
| 玩法装备 | `GameCore` 下已有 `Equipment`、`CharacterEquipment`、`EquipmentSpriteLibraryUpdater` 等玩法/视觉桥接入口 | 正式装备规则应继续归 `GameCore`，换装表现只接收可视数据，不反向拥有背包和装备规则。 |
| 动画资源 | 当前换装控制器和生成 `.anim` 原来放在 `Assets/GameData/EquipmentSystem/Animator` | 目录名应改为 `Animations`，因为里面同时有控制器、覆盖控制器和动画片段，不只是 Animator 组件配置。 |
| 原包组织 | CP1 和 Creatures 原包都把动画片段、控制器或覆盖控制器放在 `Animations/...` 下 | 项目侧应对齐这种语义：控制器与动画片段放在同一个 `Animations` 资源域内。 |
| 控制器方式 | 换装控制器只承载状态清单，0 参数、0 连线，由代码 `Animator.Play` 切换 | 继续保持；不要改回 Animator 连线状态机。 |
| Farm 动作 | `SowingSeeds / Watering / TillingSoil` 等原包 `.anim` 引用的是 `ActionInProgress(16x16)` 交互图标，不是人物身体帧 | 可作为玩法交互键，但不能作为玩家身体动作播放，也不能用别的动作冒充。 |
| 动作列表 | 2026-07-06 真实 PlayMode 审计显示换装工作台动作滚动列表展示完整 26 个动作项，其中 17 个真人身体帧动作可点击、9 个 Farm 交互键可见但禁用 | 动作库可以保留完整语义键；运行态播放只允许真实身体帧动作，缺帧项必须显式标注，不得静默隐藏或假播放。 |

## 组织建议

| 层级 | 建议落点 | 原因 |
|---|---|---|
| 装备规则、背包、穿脱、属性 | `Assets/Scripts/GameCore/...` | 这些是玩法真相，后续要进存档、战斗、Mod 和联机边界。 |
| 换装渲染、UV、Shader、工作台预览 | `Assets/Scripts/Presentation/EquipmentSystem` | 当前代码职责就是表现层；直接挪到顶层 `EquipmentSystem` 会把“表现模块”误解成“完整装备系统”。 |
| 换装动画控制器和生成动画片段 | `Assets/GameData/EquipmentSystem/Animations` | 对齐 MiniFantasy 原包 `Animations` 语义，控制器、覆盖控制器和 `.anim` 放一起。 |
| 帧数据、装备表现数据、外观数据 | `Assets/GameData/EquipmentSystem/...` | 这些是换装表现配置，继续保留 `.meta` 和引用闭包。 |

## SpriteLibrary 评估

| 方案 | 适用范围 | 不适合点 | 结论 |
|---|---|---|---|
| 全量改成 SpriteLibrary | 整套角色外观、整把武器外观、方向库替换 | 不能直接替代当前 UV/Shader 的局部衣服、头盔、肤色、描边、武器前后遮挡和像素级部位映射 | 不建议全量替换当前换装渲染。 |
| 保留 UV/Shader，SpriteLibrary 做角色基础层 | 人类/精灵/矮人/兽人等基础身体、方向、整套外观覆盖 | 仍需要维护帧数据和装备层 UV | 推荐作为后续正式角色动画主干候选。 |
| SpriteLibrary 做装备外观覆盖 | 武器、整套皮肤、整套装备套装 | 不适合单件衣服/头盔按身体区域采样 | 可用于 GameCore 装备视觉覆盖，不替代局部换装。 |

当前项目已经有 `Assets/Sprite Libraries/Characters/玩家角色精灵库.spriteLib` 和 `EquipmentSpriteLibraryUpdater`，说明 SpriteLibrary 可以作为正式角色基础视觉管线；但当前换装工作台的核心价值是像素级局部装备叠加，所以更合理的是混合方案：

- SpriteLibrary：负责基础角色库、整套外观覆盖、方向/种族切换。
- EquipmentSystem UV/Shader：负责衣服、头盔、披风、背包、武器前后遮挡、肤色和像素描边。
- Animator Controller：继续只做状态清单，所有切换由代码控制。

## 当前不建议做的事

- 不把 `Presentation/EquipmentSystem` 直接改成完整装备系统目录；这会混淆表现层和玩法规则层。
- 不把 Farm 的 `ActionInProgress` 图标动画塞进玩家控制器。
- 不把所有局部换装重构成 SpriteLibrary；那会丢掉当前 UV/Shader 的关键能力。
- 不移动第三方原包目录；只调整项目侧生成资源目录。
