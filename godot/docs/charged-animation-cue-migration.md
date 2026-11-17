# Human ChargedAttack 动画与 Cue 接缝

来源锁定 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。这只是本轮可运行模块中的表现侧，不代表整项目完成。

## 可复核来源

- `Assets/GameData/EquipmentSystem/Animations/SharedClips/ChargedAttack.anim`、相邻 meta、共享控制器和四个 `人类_*动画精灵库.asset`。
- `Assets/Scripts/GameCore/Runtime/Presentation/CuePlayGameCoreAnimator.cs`。
- `Assets/Scripts/Gameplay/Runtime/Presentation/EquipmentSystem/Runtime/CharacterActionAnimatorDriver.cs`。
- `Assets/Plugins/GAS/Runtime/Ability/AbilityTask/CommonTask/TaskPlayCue.cs`、`Runtime/Cue/GameplayCueUnit.cs`、`Runtime/System/Cue/SCueStart.cs`。

`extract_formal_human_animation.py --include-charged` 从原 Git 对象验证四向库、共享片段 GUID、无状态速度参数/跳转、PNG LFS 哈希、逐字 meta、原 sprite fileID 和区域。默认仍仅 Idle/Walk；`--include-damage` 独立可组合。输出及 PNG 必须私有，不提交仓库。

已核实六帧、每帧 0.125 秒；末尾 0.75 秒重复标签 5；不循环、不自动恢复。SE/SW/NE/NW 全部读取真实图集，并翻转 Unity 左下坐标为 Godot 左上。不是重画相似效果。

## 组合契约

`cue_play_character_animation.gd` 只提供 `on_add(owner_driver)`、`on_activate(animation_key)`、`on_remove()`。必须绑定该技能所属 ASC 的真实驱动，不能拿受击目标的驱动代替。激活失败返回 false 及 last_error，入口须显式报告，不能静默使用占位。驱动新增 `try_restore_default_animation(expected)`，使用当时的 Idle/Walk；后续不同动作或动作锁存在时不抢占。移除后清空保存的键和引用。

20004 作者 Timeline 的 TaskPlayCue 区间是帧 2 到 30（60Hz），名称 ChargedAttack。这不是动画片段长度；不要把 0.75 秒压缩成 28/60 秒。若同轮激活，区间结束时动画尚在标签 3，随后恢复当前移动动作。

严格调度差异必须保留：TaskPlayCue.OnBegin 创建、AddToAsc、Play；GameplayCueUnit.Play **只设置 ECCuePlayable**，随后 SysGrpDisplay 的 SCueStart 才调用 OnActivate。OnFinish 停止、移除、Destroy；Destroy 直接调用 OnRemove。此模块没有擅自把 Play 当成同步 OnActivate，也没有声称完整 ECS 显示调度已迁移。父级 Timeline 需在其明确的显示阶段调用激活；整段跨帧 Tick 可能开始并结束 Cue 而没有显示激活，不能凭空补播。

## 验证范围

Godot 4.7.2 的 `tools/check_formal_human_charged.gd -- <私有合同> <私有图集目录>`：真实图集四向六帧逐字 RGBA、原时间、末帧保持、不自动恢复、移除恢复 Walk/Idle、旧 Cue 不覆盖新动作、动作锁、缺少动作与重复清理。无参数明确 SKIP，不伪装素材验收通过。

未验收：完整 ECS 调度、主入口技能拥有者绑定、换装身体/头部 UV 及装备的 ChargedAttack 材质、Unity 原生画面一比一截图、整体项目迁移。不能把基本 Human 主图集冒充带装备最终画面。
