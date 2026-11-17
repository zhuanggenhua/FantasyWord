# Character command gate slice

Source: locked Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`, `CharacterCommandExecutor.cs` and `PlayerCommandRequest.cs`; base Godot `d409494`.

The real opt-in ClickMoveTest entry now creates a command router alongside its same-owner interaction resolver. `submit_human_command` checks existing actor ownership, explicit current input-target selection and accepts/capability gates (no selection returns MissingInputTarget; fallback player identity alone is insufficient); then the router preserves character → enabled → actor → dispatch validation. Explicit interaction targets cannot bypass `CanInteractNow`'s character action gate. No receiver returns BlockedByState, not success.

Fire checks the actual resolver's same-frame interaction latch before building activation context or invoking the slot. StopFire bypasses that latch. Source result order is HasAbilitySource → Valid result → rejection event. The default ability index is -1, not slot 0. Movement delegates to the existing movement executor. OpenGameMenu is still unsupported, rather than emitting an invented menu event.

## Explicit remaining formal host boundary

`bind_abilities` requires four real host adapters: fire(index, original command context, activation context), stop(index), activation-context builder(request), and failure notification(code, result). Fire returns `has_ability_source`, `result` (source Valid = 0), and `formal_gas_ability_code`. This module does **not** implement GAS, equipment selection, eligibility, activation-context construction, or effects. An unbound Fire/Stop returns InvalidCommand (unsupported migration slice), not fabricated MissingAbility. Tests inject a visibly synthetic result provider to prove routing only.

The request `actor` is the resolved projection of `GameCommandContext.Actor`, never an independent override. A dictionary `command_context.actor` is authoritative; contradictory projections are rejected. An opaque source context must be projected by its owning adapter. Target/direction/world position fields pass intact into the activation-context adapter. No input map, keyboard alias, target cell or direction is guessed here.

The existing raw movement path and diagnostic unified attack fixture remain compatible. This stage adds an executable command submission path to the real opt-in Human entry; it does not claim a complete input-to-GAS/gameplay pipeline or visual equivalence. Entry stop detaches both command router and resolver. Source interaction refresh/reset remains the only latch reset owner.


## 激活上下文的源码等价迁移

真相源仍为 `31629d5` 的 `CharacterCommandExecutor.CreateAbilityActivationContext`、
`ResolveAbilityAimDirection` 以及 `Assets/Plugins/GAS/Runtime/Ability/AbilityActivationContext.cs`。
新增 `ability_activation_context.gd` 保存只读公开属性，`ability_activation_builder.gd` 对应原构建流程：

- 先独立查询目标的真实 ASC.Cell；无 ASC 保留 null，不替换成施法者。
- 朝向依次取显式方向、目标角色根位置差、世界点位置差、角色当前目标朝向；只有必要时才查询低优先级来源。
- 原点取施法者根位置并保留 Z，不取 Static Pivot 或 Body。平方长度严格大于原 float32 `0.0001f` 才有效；零方向走无方向构造，仍保留 Cell。
- 构建不改变角色朝向，也不替代技能通过校验后的执行职责。

`ClickMoveTest.start_human_abilities` 是现有可选真实命令入口的绑定步骤：要求与当前角色 owner 一致，
将真实 Actor 根的 Godot XY 映射回 Unity XY（只翻转一次 Y，锁定此场景根 Z=0），
调用方显式提供真实目标根与 Cell 的访问函数、正式技能调用及拒绝事件。
请求 direction/world_position 和 owner 朝向均使用 Unity 坐标。交互闩锁仍先于所有上下文构建。

这不是完整 GAS 接入：技能宿主、目标生命周期与 Cell 所有权仍由真实宿主负责；没有创建假 ASC、假技能结果或补充原作没有的输入映射。
测试中的 RefCounted Cell 只是身份契约样本，不作为正式玩法。已覆盖上下文分支及真实 opt-in 入口，未据此宣称整体迁移或视觉验收完成。
