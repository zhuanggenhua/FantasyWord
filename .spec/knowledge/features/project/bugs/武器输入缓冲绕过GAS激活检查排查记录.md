---
name: 武器输入缓冲绕过GAS激活检查排查记录
description: 项目知识：bugs/武器输入缓冲绕过GAS激活检查排查记录.md：武器输入缓冲绕过GAS激活检查排查记录。
metadata:
  type: doc
  status: 已交付
---

# 武器输入缓冲绕过 GAS 激活检查排查记录

## 症状

- 基础攻击第一次出手后，输入缓冲可能在收招后再次触发武器执行。
- 如果第二次触发只走武器状态机，不重新检查 EX-GAS 激活条件，就可能绕过正式冷却或正式资源消耗规则。

## 误判风险

- 只看 `CharacterAbilitySet.FireAbility()` 的首次 `CanFire()` 会误以为所有出手都被 GAS 拦住。
- 只测“按键第二次立刻返回 OnCooldown”不能覆盖输入缓冲，因为缓冲是在武器状态机后续 tick 中消费。
- 只把 `Stop` / `Interrupted` 从 busy 状态里排除，不能证明缓冲消费路径也重新进了 GAS。

## 真实根因

- `WeaponExecutionRuntime` 原本在 `RequestUse()` 之外的后续路径里可以直接 `StartUseSequence()`。
- 输入缓冲和自动重复出手属于武器执行状态机内部路径，不会自然回到 `CharacterAbilitySet.FireAbility()`。
- 因此需要在“真正开始一次武器执行序列”前挂统一启动门，而不是只在外部输入入口检查一次。

## 修复点

- `WeaponExecutionRuntime` 构造时接受 `canStartUseSequence` 回调。
- `ActiveAbilityBase` 把启动门接到同一份正式规则检查：EX-GAS `CheckActivation()`、本地回退冷却/法力、能力许可。
- `WeaponExecutionRuntime.StartUseSequence()` 在每次真正开始序列前调用启动门。
- `MeleeAttackAbilityEditModeTests` 增加输入缓冲回归：第一次出手扣蓝并进入冷却后，缓冲消费不得绕过 EX-GAS 冷却继续扣蓝。

## 必查项

- 检查 `WeaponExecutionRuntime.StartUseSequence()` 是否仍是所有武器序列开始的唯一入口。
- 检查输入缓冲、自动重复、停止后消费缓冲是否都会经过该入口。
- 检查 `ActiveAbilityBase.CanFire()` 和武器内部启动门是否共用同一份启动规则，不要拆成两套判断。

## 验收口径

- `MeleeAttackAbilityEditModeTests` 必须通过，并覆盖输入缓冲不绕过 EX-GAS 激活检查。
- `FormalDamagePipelineEditModeTests` 必须继续通过，证明伤害管线没有被武器启动门改坏。
- OpenSpec strict validate 必须通过。
- Unity 当前正式场景不能因为验证残留 dirty。

## 验证记录

- `python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"EditMode","testClass":"MeleeAttackAbilityEditModeTests","includeMessages":true,"includeStacktrace":true,"requestId":"melee-after-assets-refresh-20260702"}'`：Passed，`failedTests = 0`
- `python .codex/skills/aibridge/bridge.py tests-run '{"testMode":"EditMode","testClass":"FormalDamagePipelineEditModeTests","includeMessages":true,"includeStacktrace":true,"requestId":"formal-damage-pipeline-after-weapon-start-gate-20260702"}'`：Passed，`failedTests = 0`
- `npx openspec validate refactor-melee-ability-authoring --strict`：Passed
- `python .codex/skills/aibridge/bridge.py scene-list-opened`：`Assets/Scenes/ClickMoveTest.unity`，`isDirty = false`

## 关联文件

- `Assets/Scripts/GameCore/Runtime/Combat/Weapons/WeaponExecutionRuntime.cs`
- `Assets/Scripts/GameCore/Runtime/Combat/Abilities/Active/ActiveAbilityBase.cs`
- `Assets/Editor/GameCore/Tests/MeleeAttackAbilityEditModeTests.cs`
