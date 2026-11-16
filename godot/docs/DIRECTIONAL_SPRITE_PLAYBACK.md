# 四向精灵与动作阶段分离

本阶段依据锁定 Unity `31629d5` 的 `DirectionalSpriteLibraryDriver`、`CharacterAnimationDirections`、`EquipmentWorkbenchAnimatorControllerTool.BuildResolverClip` 和已有动作恢复驱动。原入口切换四向精灵库后立即解析当前动作标签，再通知换装渲染器，不重播 Animator，不重新计算伤害恢复时间。

Godot 对应入口为 `directional_sprite_playback.gd`。显式注入 Sprite2D、空 AnimationPlayer 和动作清单，通过原生离散动画属性轨道选择动作标签。清单由已核实的源动画与精灵库派生，包含动作时长、循环、关键帧时间、整数标签和 SE/SW/NE/NW 四组纹理数组。标签只是精灵库条目的序号，不是图集列号；纹理可以是引用原图区域的 AtlasTexture，支持稀疏原图位置及源生成器已经补齐的重复末帧。

`set_direction` 只解析新方向的当前标签，依次发出 `sample_resolved` 和 `direction_applied`。方向来源继续使用 Unity XY，`set_facing_direction` 通过独立四向规则处理近轴方向；近零输入不重新解析或通知。播放、锁定和伤害自动恢复仍归 `character_action_animator_driver.gd`，本模块不另设动作计时器。

配置前验证全部资源，不覆盖已有动画库、不猜缺失方向或纹理、不把小数标签截断成有效标签。失败返回 false，并在 `last_error` 说明问题；调用者必须停止该角色的表现接入，不能以无图状态继续宣布成功。清单的整数标签是运行时契约；JSON 迁移器需要先校验数字确为整数再显式转换，不能丢失序号含义。

测试使用自造的小纹理和真实 AnimationPlayer，验证稀疏标签映射、方向切换不改阶段和期限、先解析再通知、末帧保持，以及原期限恢复到当前移动动作。自造纹理仅用于自动测试，不能作为正式美术。独立私有素材验证采用原项目真实 Idle、Walk、Dmg 精灵区域，不进入公共提交。

尚未证明完整 Unity 画面对照或最终玩法接入。装备 UV 着色器、头发、胡须、眼睛与装备帧同步仍需迁移；本阶段暴露方向通知不等于这些层已实现。正式 HP 事件到动作恢复的端到端入口也需另行验收。
