# 移动原生诊断场景

## 对象与边界

入口 `keyboard_motion_fixture.tscn` 只负责把已迁移的键盘/点击命令、真实原生角色身体和阻尼相机接到可运行场景。不是正式主场景，不替换原来的 `ClickMoveTest`，也不是美术、完整玩家生命周期或正式可试玩版本验收。

基线为 Unity `31629d5`：`Assets/InputSystem_Actions.inputactions` 的两个键盘组合，`InputSystem.OnMovePerformed/OnMoveCanceled`，`CharacterMovement`，`Movable.MotionRuntime` 与基础角色预制体的速度 4、加减速 10、阈值 0.05。身体保持原来的胶囊尺寸、偏移和查询掩码 7752。参数在诊断宿主显式注入，不代替 GAS、装备或状态修正后的属性。

按原场景 `ClickMoveTestControlPanel` 初始值选择点击模式；Tab 在方向与点击间切换并清掉在途移动。左键只在按下时提交，来源是无自定义交互的 Gameplay/Click Button 和 Input System 1.18.0 `InputActionState` 的默认 Button 分支，松开只 canceled，不再次 performed。Godot 本地已消耗的 UI 事件不进入诊断点击入口，但这不等于原版 EventSystem/UIPointerUtility 已迁移。未接失焦输入复位、完整玩家绑定生命周期、手柄、墙、NPC、推力、传送和动画。移动物理使用当前 Godot 固定步长，相机在其画面更新中显式推进，不声明等同 Cinemachine Brain SmartUpdate 时序。

## 运行

```sh
Godot --path godot res://validation/scenes/keyboard_motion_fixture.tscn
```

先按 Tab 切到方向模式，再用 WASD 或方向键移动。加载源规则后可切回点击模式，用左键点地寻路。没有原图数据时明确显示“未加载原地图，点击停用”，拒绝点击，不制造备用地图或直线兜底。诊断标记和色块不是正式素材，不能作为迁移效果截图交付。

可先用现有 `tools/extract_clickmovetest_rules.py` 在仓库外生成私有规则 JSON，再传入绝对路径：

```sh
Godot --path godot res://validation/scenes/keyboard_motion_fixture.tscn -- --rules=/absolute/private-rules.json
```

只接受锁定提交、指定 Tilemap、900 行且含 649 个图节点的源数据。规则仅画坐标供观察，不将不可行走单元擅自做成物理墙；原静态 Default 几何不在地形查询掩码里。不把私有 JSON 或截图加入 Git。

## 验证

`tests/test_live_keyboard_fixture.gd` 从同一个场景实例出发，通过 Godot Viewport 投递键事件，实际跑身体和相机：移动、输入组竞争/交接、门禁下释放、重复输入、切换模式和停止后的稳定位置。额外传入私有规则数据的同一测试还覆盖视口左键→原图路径→原生身体，松开不重复发命令，切换模式清掉路径。既有 `tests/run.sh` 自动包含该测试。无 Unity 原生对照、OS 键盘操作或截图验收；完整移动场景仍未验收。

待正式宿主与原资源链完整迁入后，此诊断仍只保留为测试入口，不能成为第二套玩法 owner。
