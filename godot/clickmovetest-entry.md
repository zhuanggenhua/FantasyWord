# ClickMoveTest 原生启动切片

这是**逻辑接入阶段，不是正式场景交付或视觉验收**。源锁定 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`；不更改 Unity 主分支。原场景美术、地图层级、GAS、NPC、UI 和完整系统启动尚未接齐；不以测试色块、线框角色、假地图或自动默认资源补齐它们。`project.godot` 仍无正式主场景。

## 本轮对象、依据和边界

- 对象：`gameplay/clickmovetest/entry.tscn`，显式依赖注入的原生单角色启动切片。
- 真相：`Assets/Scenes/ClickMoveTest.unity`、`0_CharacterActor_Base.prefab` 及其 `0_Character_Base.prefab` 继承、`InputSystem.cs`、`PlayerCameraRig.cs`、`ClickMoveTestControlPanel.cs`，复用已迁移 GameCore 移动、导航、相机与输入 owner。
- 入口：Godot 4.7.2；`start_logic` 只接调用者给定的动作 owner、锁定私有规则文件、玩家 provider、地图 provider/事件、UI 门禁。不扫描节点寻找替代依赖。
- 验收：实际 Viewport 输入事件、原地图路径、原生物理推进、相机绑定前后状态、控制角色失效拒绝；不推断 Unity GameView、完整玩法或像素对齐。

## 不能混淆的原始层级

| 原始事实 | 当前映射 |
|---|---|
| 玩家 Actor 根 transform `6241793363770211169` 场景位置 `(0,0,0)`；根上 CharacterActor 和继承 Rigidbody/Collider | `玩家角色` 是 AnimatableBody2D，位于原点，持有运动能力与碰撞形状 |
| 表现 Body transform `2101494329101190424` 的场景覆盖 `(0.75,-3.1)` | 原生局部位置 `(0.75,3.1)`，仅保留空表现挂点，不把它当运动主体，不绘制假角色 |
| 胶囊宽高 `.78/.86`、offset `(0,.42)` | 半径 `.39`、高 `.86`、原生偏移 `(0,-.42)` |
| 相机序列化 `(0.75,-3.1,-10)`，初始 TrackingTarget 为表现 Body | 原生相机初始 `(0.75,3.1)`；这不是运行时绑定之后的最终跟随目标 |
| PlayerCameraRig 优先地图覆盖，其次 controlled CharacterActor.transform | 复用 `player_camera_binding.gd`；无地图覆盖时跟随 Actor 原点，不能沿用表现 Body |
| ControlPanel `m_forceClickToMoveOnStart:1` 只在找到玩家后首次生效 | 配置 movement 后切换一次点击模式，后续 Tab 可切换，不每帧强制 |
| ClickMove 先检查阻塞、相机、角色、UI，再投影后发玩家命令 | 原生未消费鼠标左键事件，调用既有 command owner，外部 UI 门禁仍显式注入 |

源 `Movable.MotionRuntime` 使用 `max(Constants.AcceptableDistanceFromTarget, stoppingDistance)`；`.05` 的点击停止请求实际取 `.1` 下限。验证不要求瞬移到目标中心。

## 文件职责与生命周期

- `entry.tscn`：唯一原生作者层级，显示 Actor/表现 Body/碰撞/相机引用与初始配置。
- `entry.gd`：单次启动、输入、物理时序与退出解绑。此业务组合属于 Gameplay，GameCore 不认识 ClickMoveTest。
- `actor.gd`：继承现有物理 owner，仅增加既有 camera binding 要求的 `teleported` 通知合同；不声称完成传送。
- `tools/run_clickmovetest_logic.gd`：明确隔离的 CLI 逻辑宿主，提供基础速度 4 的测试 owner，无 GAS；不进入正式主场景。
- `tests/test_clickmovetest_entry.gd`：无需原图的静态层级、缺依赖及畸形数据门禁回归。

当前只允许输入同一个显式 Actor。provider 初始化必须指向它；控制角色变化后旧 Actor 不再接受新输入；已经接受的路径仍由动作 owner 正常推进，不因绑定变化擅自取消。不会创建第二玩家或替用户决定队伍目标。`map_provider` 返回 null 或实现既有 camera binding 所要求的 `get_camera_target/get_level_bounds` 的真实地图对象。碰撞 mask 0 只保留查询式移动，不假定 Unity 接触矩阵。场景未接私有碰撞世界，不能声称墙体交互完成。

## 独立执行

先以已存在的 `tools/extract_clickmovetest_rules.py` 从锁定 Unity 源生成**本地私有**规则文件，不提交原始场景、规则文件、图片或截图。

```sh
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --path godot --script res://tools/run_clickmovetest_logic.gd -- --logic-only --rules=/private/rules.json --smoke
```

去掉 `--smoke` 可持续运行原生输入和物理循环，但没有美术显示，**不能作为可试玩版本交付**。缺少 `--logic-only` 或私有文件、源版本错误、规则结构不完整会退出失败；不会生成替代资源。自动测试仅投递真实 Viewport 事件，不伪称操作系统硬件输入或截图验收。

全套回归：`GODOT="$GODOT" bash godot/tests/run.sh`。专用私有地图测试和全套测试必须分别执行，不能用一项通过宣称整体迁移完毕。
