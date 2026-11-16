# 同一移动场景中的源普攻切片

`movement_combat_fixture.tscn` 现在包含原 `ClickMoveTestGasBasicAttackValidator` 的显式测试装配：槽 0 / 键盘 1 / Ability 20001。槽 1 的 Q/2 蓄力诊断保留。使用真实移动身体的当前位置、当前 MovementBased 朝向，不自动转向目标。

20001 使用 Timeline 101（命中帧 8、生命周期 30）、原四点 Polygon catcher、Layer 7 子 Hitbox 身份和 Effect 2003。基础物理伤害 flat4/scale1；背刺 dot<=-.35 时附加 flat3/scale0，两段 PushMode=Disabled。不会调用蓄力默认击退。目标方向、位置在命中时读取，伤害通过现有 formal_damage_application 适配器处理。

输入接入源 SemiAuto 门：一帧准备、30/60 恢复、.25 秒缓冲、松手中断准备或恢复。必须按住 1 到命中帧；快速点击不保证出手。开始和提交时重新查装备及当前诊断资格，不能复用旧的槽位授权。两条活动时间轴互斥，按原 Event.Attacking 语义局部阻止移动。

边界：仍为无原美术的矩形测试角色诊断，不是正式关卡/正式 GAS。资格布尔值不是完整属性、消耗、冷却或标签拥有者；测试随机数固定50，尚未接正式随机源。Polygon 查询仅支持现有矩形目标子集。未宣布完整战斗或一比一视觉验收。

验收 `test_unified_basic_attack.gd` 通过 Viewport 真实键事件移动入范围，按住1等待真实帧调度，HP50→37且无位移/推力，再按住并释放 Q，HP37→16且出现默认推力。另测交互拦截、缺槽及出手前移除装备；现有移动、蓄力及 Polygon 独立测试继续保留。
