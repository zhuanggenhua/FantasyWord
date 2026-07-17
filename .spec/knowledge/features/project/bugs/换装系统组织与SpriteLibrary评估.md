---
name: 换装系统组织与SpriteLibrary评估
description: 项目知识：bugs/换装系统组织与SpriteLibrary评估.md：换装系统组织与SpriteLibrary评估。
metadata:
  type: doc
  status: 已交付
---

# 换装系统组织与 SpriteLibrary 评估

> 范围：`Assets/Scenes/EquipmentSystemDemo.unity`、`Assets/Scripts/Presentation/EquipmentSystem`、`Assets/GameData/EquipmentSystem` 和 MiniFantasy 原包动画组织。
> 结论时间：2026-07-13。

## 已锁定事实

| 项 | 当前事实 | 结论 |
|---|---|---|
| 脚本模块 | `Assets/Scripts/Presentation/EquipmentSystem` 只负责换装表现、UV、Shader、预览 UI、编辑器工具 | 它不是完整物品/背包/装备规则系统；`Presentation` 这一层不是多余包装，而是在表达“表现层”。 |
| 玩法装备 | `GameCore` 下已有 `Equipment`、`CharacterEquipment`、`EquipmentSpriteLibraryUpdater` 等玩法/视觉桥接入口 | 正式装备规则应继续归 `GameCore`，换装表现只接收可视数据，不反向拥有背包和装备规则。 |
| 动画资源 | `Assets/GameData/EquipmentSystem/Animations` 只保留共享 Controller、每动作一个 `SharedClips` 片段和每角色四方向 `SpriteLibraries` | 角色或方向变体都不得生成独立动画片段或覆盖控制器。 |
| 原包组织 | CP1 和 Creatures 原包提供各人形种族四方向帧素材 | 项目侧把素材收口成相同动作分类、相同帧标签的四向 SpriteLibrary；不使用左右镜像复用。 |
| 控制器方式 | 换装控制器只承载动作状态，0 参数、0 连线，由代码 `Animator.Play` 切动作 | Animator 状态不得包含 `_SE/_SW/_NE/_NW`；方向变化不得调用 `Animator.Play` 或重置播放进度。 |
| Farm 动作 | `SowingSeeds / Watering / TillingSoil` 等原包 `.anim` 引用的是 `ActionInProgress(16x16)` 交互图标，不是人物身体帧 | 可作为玩法交互键，但不能作为玩家身体动作播放，也不能用别的动作冒充。 |
| 动作列表 | 2026-07-06 真实 PlayMode 审计显示换装工作台动作滚动列表展示完整 26 个动作项，其中 17 个真人身体帧动作可点击、9 个 Farm 交互键可见但禁用 | 动作库可以保留完整语义键；运行态播放只允许真实身体帧动作，缺帧项必须显式标注，不得静默隐藏或假播放。 |

## 组织建议

| 层级 | 建议落点 | 原因 |
|---|---|---|
| 装备规则、背包、穿脱、属性 | `Assets/Scripts/GameCore/...` | 这些是玩法真相，后续要进存档、战斗、Mod 和联机边界。 |
| 换装渲染、UV、Shader、工作台预览 | `Assets/Scripts/Presentation/EquipmentSystem` | 当前代码职责就是表现层；直接挪到顶层 `EquipmentSystem` 会把“表现模块”误解成“完整装备系统”。 |
| 换装共享控制器、共享动画片段和角色四向精灵库 | `Assets/GameData/EquipmentSystem/Animations` | `SharedClips` 只按动作分类动画 `SpriteResolver.m_SpriteKey`；每个角色的 SE/SW/NE/NW 库使用相同分类和帧标签，只保存方向对应的具体 Sprite；工作台角色选项和运行时方向驱动直接持有四个原生 `SpriteLibraryAsset` 引用，不再额外生成动画变体包装资产。 |
| 帧数据、装备表现数据、外观数据 | `Assets/GameData/EquipmentSystem/...` | 这些是换装表现配置，继续保留 `.meta` 和引用闭包。 |

## SpriteLibrary 评估

| 方案 | 适用范围 | 不适合点 | 结论 |
|---|---|---|---|
| 全量改成 SpriteLibrary | 整套角色外观、整把武器外观、方向库替换 | 不能直接替代当前 UV/Shader 的局部衣服、头盔、肤色、描边、武器前后遮挡和像素级部位映射 | 不建议全量替换当前换装渲染。 |
| 保留 UV/Shader，SpriteLibrary 做角色基础层 | 人类/精灵/矮人/兽人等基础身体、方向、整套外观覆盖 | 仍需要维护帧数据和装备层 UV | 推荐作为后续正式角色动画主干候选。 |
| SpriteLibrary 做装备外观覆盖 | 武器、整套皮肤、整套装备套装 | 不适合单件衣服/头盔按身体区域采样 | 可用于 GameCore 装备视觉覆盖，不替代局部换装。 |

换装动画正式职责边界：

- `CharacterActionAnimatorDriver`：只负责动作选择、动作锁和 Animator 动作状态，不读取或保存方向。
- `DirectionalSpriteLibraryDriver`：只负责方向选择、消费四向 `SpriteLibraryAsset` 引用、切换当前 `SpriteLibraryAsset` 及同步换装渲染方向；切方向不重播动作。
- `CharacterFrameData`：只负责 UV、锚点、帧作者数据和装备合成帧，不持有派生 SpriteLibrary 方向库引用。
- SpriteLibrary：负责基础角色库、整套外观覆盖、方向/种族切换；每个角色固定四个真实方向库，不使用 `flipX`。
- EquipmentSystem UV/Shader：负责衣服、头盔、披风、背包、武器前后遮挡、肤色和像素描边。
- Animator Controller：只有一个共享动作状态清单，动作状态名和共享片段名不含方向。

`GeneratedClips`、`Animations/Overrides`、角色级 `AnimatorOverrideController`、方向化 Animator 状态/片段/分类和直接动画 `SpriteRenderer.m_Sprite` 均由 `scripts/Invoke-EquipmentSystemStaticGate.ps1` 阻止回流。

动画资源构建器只维护派生动画资产，并把每个角色的四向 `SpriteLibraryAsset` 引用回写到工作台目录；它不负责场景或 Prefab 组合，避免重建资源时覆盖正在编辑的场景。独立 `CharacterAnimationVariantSet` 包装层已作为过度抽象移除，静态门禁会阻止其回流。

## 当前不建议做的事

- 不把 `Presentation/EquipmentSystem` 直接改成完整装备系统目录；这会混淆表现层和玩法规则层。
- 不把 Farm 的 `ActionInProgress` 图标动画塞进玩家控制器。
- 不把所有局部换装重构成 SpriteLibrary；那会丢掉当前 UV/Shader 的关键能力。
- 不移动第三方原包目录；只调整项目侧生成资源目录。
