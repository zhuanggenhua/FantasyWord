# ClickMoveTest 原手柄移动与模式切换

依据锁定 Unity `31629d53` 的 `Assets/InputSystem_Actions.inputactions`、原测试面板与角色移动。F5 仍按原面板从 ClickToMove 启动。Gameplay 的 Tab 和右摇杆按下调用同一个真实主角命令，重置旧路径与旧移动方向；它们不是两次切换。原 Button 没有进入动作图时的初始按压检查。切模式不重新启用 Gameplay，不重新读取持续未变的轴。方向模式拒绝点击寻路。

本地手柄 0 左摇杆：Godot 的屏幕轴 Y 转换到原命令正 Y 向上。Unity Input System 1.18 的控制径向死区默认 0.125–0.925，原绑定再 NormalizeVector2 与 StickDeadzone；通过归一化的摇杆按单位方向走，不套用额外的比例速度。与两个键盘组合共用一个原 Move 动作，竞争使用控制端量级而不是归一化后的命令值；没有叠加三个方向。原 Unity PlayerInput 的设备配对/自动切控制方案、平台同时轴事件的确切顺序、断线/失焦与实物手柄对照未验收。

Pause 停止现有 Move，但记录暂停期间的物理轴。与 Button 不同，原 Value Move 在动作图启用后的首个输入更新采样；源 Input System 关闭旧动作时清除按压，原游戏又在新动作刚开启时检查释放门禁，所以正常返回时按住摇杆预期在后续采样重新按当前方向移动，无需归中。动过或归中的轴按最新值；这来自 [Unity Input System 1.18 源码](https://github.com/Unity-Technologies/InputSystem/blob/1.18.0/Packages/com.unity.inputsystem/InputSystem/Actions/InputActionState.cs#L771-L861) 及其 [初始采样](https://github.com/Unity-Technologies/InputSystem/blob/1.18.0/Packages/com.unity.inputsystem/InputSystem/Actions/InputActionState.cs#L1122-L1209)，不是双引擎同机实测。

`test_source_gamepad_movement_entry.gd` 从真实 F5 入口注入 Godot 事件，点击产生原路线、切模式清路、摇杆在现有角色上实际斜走并播放 Walk、回中停止、暂停保持/转向/松手与返回，以及按住 Tab/右摇杆别名抑制重复。无私有素材运行独立动作合同，将地图、动画和暂停分支明确跳过。不涉及手柄瞄准、D-pad 菜单导航或整项目验收。

## 原地形坡道的方向解析

锁定 `TerrainNavigationMap.TryResolveRampMovementDirection`（262–332）和
`Movable.MotionRuntime.ResolveMovementInput/ResolveTerrainMovementInput`（487–561）。
原图规则层 1361196487 有六个默认层坡道格：(0,2)、(-1,3)、(0,3)、(-4,4)、
(-5,5)、(-4,5)。只有位于有作者朝向的坡道格时，才按右、左、上、下检查可行走
且高差合法、同朝向坡道或普通出口；比较当前实际物理根到邻格中心的单位向量与原
输入的点积，严格大于 0.25 才采纳，平手保留原顺序。没有候选时不清零输入。
实际主角与训练假人使用同一有效地图和各自物理根；输入大小、平滑、原意图朝向、
碰撞和移动成功后的 Walk 表现照旧。不提前扭转已规划的点地路线，不改路径图或
阻挡掩码，也不为不支持的多层地形增加猜测。地面投影与单位仍用已锁定的原网格。

`test_source_ramp_movement_entry.gd` 从真实 F5，把主角物理根置到原低坡和原平地，
通过正式 Tab 切换方向模式，用键盘左上及真实摇杆事件检查不同邻格、平手顺序、物理
位置、普通地面的斜向移动和 Walk；再次切回点击模式，坡道格内真实点地仍斜向跟随
精确目标。夹具不替换地形及角色；未逐个跑遍六个坡道、实物手柄、实际假人走坡
或 Unity 原生截图对照。

`test_source_trainer_ramp_entry.gd` 独立覆盖实际假人：只把正式假人和主角的物理根
置于原地图格，不写入 AI 目标、路径、速度或方向。将主角摆到实际可走格 (12,-3)，
距离超过原追击脱离半径；假人从原高坡 (0,3) 沿原出生点归位路线的中间转向组运动，
首个压缩路点 (2.5,3.5)，东侧合法出口 (1,3) 的中心为 (1.5,3.5)。
测试分别采集上一拍安全方向/速度、消耗前后的倍率与零单体校正、AI 原朝向、实际速度
和刚体移动后的格子：实际移动朝东侧低处，但 AI 原安全意图与朝向仍未改写。此段
没有点地 MoveOrder、攻击目标或击退。仅断开假人方向坡道回调的隔离样本仍能踏进
目标格，但会直接沿原始安全向量而不是合法邻格中心，故仍被判失败。
其余坡道、存在非零多代理校正、追敌走坡及 Unity 双端画面对照没有验收。
