# 普通攻击命中帧诊断

## 已锁定的源

Unity `31629d5` 的 `exgas_tbability.json` 中技能 20001 使用 Timeline 101；`exgas_tbtimelineability.json` 中第 8 帧的 `TaskApplyEffects` 应用效果 2003，生命周期 30 帧。真正使用的是 **CatchAreaPolygon2D**，不是同项目另一条测试的 Box catcher：相对四点 `(0.175,-0.25)`、`(1.125,-0.25)`、`(1.125,0.55)`、`(0.175,0.55)`，Hitbox 掩码 128。

`ALTimelinePlayer` 用累计 float `Time.deltaTime × GASTimer.FrameRate(60)` 追帧，不能把攻击帧直接当物理帧。目标捕获在 `TaskApplyEffects.OnBegin` 执行，按 `Movable.TryGetGas2DFacingDirection` 当时的 lookAtDirection 旋转形状，而不是起手快照或 Transform 的旋转。

效果 2003 基础伤害为物理 `4 + 1 × 物攻`；背刺条件为目标朝向与目标到攻击者方向点积不大于 -0.35，额外物理伤害 3。两条效果 PushMode 都为 Disabled。GameConfig 允许暴击与闪避；诊断保留这两个开关，注入固定 roll 50 和 luck/agility 0，不伪称随机序列复现。

## 实现与职责

- `polygon_hitbox_query.gd`：真实 Godot 世界包围盒粗筛（最多 64 候选），源多边形与矩形子碰撞体窄筛；排除来源并按目标身份去重。只覆盖矩形子 Hitbox，不能把 Circle、Capsule 或任意碰撞体当成已迁移。物理查询结果顺序、候选溢出及边界浮点精度未与 Unity 原生对照。
- `attack_hit_frame.gd`：只处理命中任务的源时钟切片和停止；不代持完整 Timeline、GAS 资格、消耗、Cue、输入缓冲或状态标签。
- `basic_attack_fixture.gd`：使用原 EditMode 测试的站位和 1×1 子触发框，以显式诊断属性 owner 接 `formal_damage_application.gd` 的有序回调。基础测试攻击者 30 HP / 10 物攻，目标 40 HP / 2 物防，面对攻击者时实际扣 13，最大生命保持 40，无推力。背刺另扣 2。角色身体仍是真实原生移动身体，受击框与身体分开。

**当前生命存储只是诊断 owner，不是原 EX-GAS 属性 Modifier 系统迁移。** 没有技能赋予、攻击输入、资源持久化、死亡生命周期、动画或正式美术。命中流程的接入不等于完整攻击或游戏可玩交付。

## 运行与验证

```sh
Godot --path godot res://validation/scenes/basic_attack_fixture.tscn -- --diagnose-attack
```

`--diagnose-attack` 只表示在诊断中模拟“该技能已经获准激活”，等两物理帧完成碰撞注册后开始一次命中时钟；它不是发明的新攻击键或正式技能前提。省略该参数只打开诊断场景，不自动造成伤害。另加 `--verify-attack` 可在首次时序结束后断言扣 13、最大生命不变、其他目标不变且没有推力，并退出；它只用于诊断自动检查。

`tests/test_basic_attack_fixture.gd` 实例化同一个场景，覆盖命中帧前后、重复 hitbox 去重、自身/范围外排除、最大生命不变、原回调顺序、普通攻击与背刺不推、命中帧转向、生命周期结束、中断和无效朝向。测试直接注入可控 delta，不冒充实际 Unity PlayMode 时序。

诊断线框和文字仅是内部观察工具，不作为原游戏视觉验收截图或替代美术交付。
