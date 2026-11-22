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


## 点击观察与 UI 命中策略（增量，未完成全部迁移）

依据锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的
`ClickMoveTestControlPanel.OnGameplayClickPerformed`、`UpdatePendingClickInspection`
及 `UIPointerUtility.IsBlockingUIRaycastResult`，加入以下独立切片：

- `entry.gd` 的 `_input` 在原生 GUI 消费前观察左键按下；原 `_unhandled_input`
  仍是唯一点击派发入口。松开不记录、不派发。不通过观察补发 GUI 消费的点击。
- 记录帧、屏幕位置、显式 UI 谓词结果、已绑定单角色输入目标是否仍有效、该角色动作能力、
  模式和投影。UI 阻挡不跳过观察投影；无已绑定角色时投影无效且位置为零。
  当前目标合同仅是本入口的单角色绑定，不代表完整 `PlayerSystem.TryGetCurrentInputTarget`。
  动作能力来自已注入 owner，不代表 GAS 全部接入。
- 第一次更新仅将等待计数从 1 减为 0；第二次读取届时实际角色订单和运动根位置。
  新点击覆盖旧待观察点击并重新计数。`order_before_dispatch` 是额外先前状态证据；
  `order_after_updates` 可能是旧路径仍在执行，绝不是“该次点击已生成新命令”的因果结论。
- `ui_guard` 必须是纯查询：观察和派发各自查询，不缓存前次结果代替派发门禁。
  Godot `Control.mouse_filter=STOP` 的原生消费与该显式谓词是两个独立事实。
- `pointer_blocker_policy.gd` 仅接收源语义命中元数据：对象是否存在、精确名称、
  `GetComponentsInParent(includeInactive:false)` 已枚举的近到远 CanvasGroup 列表、
  Graphic 是否存在及 raycastTarget。先判 blocksRaycasts=false，再判 ignoreParentGroups，
  不另按组件 enabled 过滤。忽略精确名称 Mask，但扫描其余所有命中，不忽略独立下层阻挡。
  无正式 EventSystem 时返回 false。未实现 Unity RaycastAll、CanvasGroup 的原生节点映射、
  Selectable 选择或 Godot hover 等价；此策略尚未冒充真实 UI 查询接入。

验证：Godot **4.7.2**；新增纯观察/策略测试。专用 `--logic-only --smoke` 在私有源规则下
通过真实 Viewport 注入和 Control STOP 验证“GUI 消费仍可观察，派发保持零”，包括显式
UI 谓词为 true 和 false 的两种情况；并验证延迟实际读回和被拒绝点击保留旧订单。
这些不是 OS 鼠标硬件测试、原版截图或完整玩法验收；未加入替代视觉资源。

专用烟测的 `ui_guard` 实际调用上述纯策略：Mask 单独存在时不阻挡，加上独立下层命中才阻挡。
这些命中是测试明确注入的源语义元数据，不是从 Control 消费推断所得，不是原场景射线结果。

鼠标 Point 的可选动作生命周期、来源及未验收边界见 [鼠标 Point 切片](mouse-point-port.md)。

## 从项目正常启动原 ClickMoveTest

锁定 Unity 31629d53 的全局 EditorBuildSettings 将 ClickMoveTest 列为第一个启用场景；
该场景从 Gameplay 开始、主角在原点、地图检查点与 Playtest 存档未配置。Godot 的
project.godot 运行入口复用同一原图装配：导入原作者资源后执行 godot --path godot，
或从继承同一环境的编辑器按 F5。无需 --script 或 --source-preview。
初始时间倍率为 1，控制、镜头和移动均使用同一真实主角；玩家身份从预摆标识替换为
player，不触发写存档或合成地图过场。原过场的启动画面透明且不拦指针，此阶段没有
搬入切图过渡宿主。

除了下一节的基础输入，还需要 FORMAL_PANEL_SILVER 和 FORMAL_PANEL_CJK 对应原字体，
以及 FORMAL_WATER_REFLECTION_MASK 对应原遮罩。正常入口装配原诊断面板、原树和主角本体
倒影，1 为原普攻、Q 或 2 为原喷火；可在原草地上点燃、进入燃烧区并触发真实接触受击与
致死。启动不预点燃任何格。唯一原活动训练假人随地图出现，使用原出生点、体力、路径及普攻，
可以与同一主角双向结算并进入各自原死亡阶段；不会另外生成诊断替身。
正常入口用 FORMAL_PLAYER_DEATH_ANIMATION 和 FORMAL_PLAYER_DEATH_MATERIAL 替换下文的
两个 DAMAGE 合同。对同一个原主角运行两个提取脚本时加 --include-damage --include-attack
--include-death，图集目录含原 Attack、SpinDie 及其头身 UV。FORMAL_FLAMETHROWER_CUE
指向原 PNG 与 OGG 私有目录；具体文件名见原玩家技能诊断。假人另需
FORMAL_TRAINER_ATTACK_DEATH_ANIMATION、FORMAL_TRAINER_ATTACK_DEATH_MATERIAL（原独立
假人 Attack/SpinDie 合同）与 FORMAL_TRAINER_ATTACK_TEXTURES。普通场景共享同一非固定随机源，
保留作者调用、浮点闭区间和整数 1–99；未宣称 Unity 位级随机序列。
缺失或校验不通过的资源会报具体缺项并退出，绝不加载占位关卡。原始文件只保留在有
权限的本机或云端，不随仓库公开。

已验证入口是共享的 ClickMoveTest 单人启动、实际地图、点击/WASD、镜头和静态 UI。
Unity 正式 GameManager 启动全链、SampleScene、其他战斗与死亡副系统、存读档、过场切换、Unity
原生同帧画面和构建配置覆盖仍未验收。原图和行为测试不等于整个项目迁移完毕。

## 原图移动预览

使用 `godot --path godot --script res://tools/run_clickmovetest_source_preview.gd -- --source-preview`。
这是单独的诊断入口，不改项目正常启动选项。须在有权限的本机或云端通过环境变量传入下列输入：

- `FORMAL_SURFACE_RULES`：锁定 ClickMoveTest 的地图规则 JSON。
- `FORMAL_SURFACE_ASSETS`、`FORMAL_GROUND_LAYERS`、`FORMAL_BURNING_TILE_PNG`：原地表登记 JSON、原地面投影目录与实际残火图。
- `FORMAL_PLAYER_DAMAGE_ANIMATION`、`FORMAL_PLAYER_DAMAGE_MATERIAL`：原玩家独立动画与双 UV 材质合同。
- `FORMAL_PLAYER_TEXTURES`：角色私有图集目录，须含玩家合同对应的图集、`uv` 与 `appearance`；不能用训练假人合同替代。

没有足够输入时明确拒绝，不会启动占位场景。左键点击原地图移动，Tab 切换控制方式，
WASD 按原方向移动；相机跟同一演员，动作使用原 Idle/Walk。可加 `--smoke`
以验证启动和实际 Godot Viewport 键鼠链；注入操作不是实际设备或 Unity 画面对照。
Mouse Point 有自己的位置入口；本预览点击保留现有 Godot 鼠标事件桥，不等于完整 Unity
Input Actions / UIRoot。原序列化的 ClickMoveTest MapInfo 未启用相机覆盖或边界；
本预览未移植正式 SampleScene、GAS 装配、存档、完整地图碰撞或局内装备。

可加 `--trainer-diagnostic` 在同一预览挂入原场景唯一启用的训练假人。角色来源为
`31629d53` 中 ClickMoveTest 的 `735002000000000003`（不是禁用的转向测试变体），
使用原出生点、路径、朝向、属性、感知、游走、归位与预制体追加的能力 20001。
还须传入 `FORMAL_TRAINER_ATTACK_ANIMATION`、`FORMAL_TRAINER_ATTACK_MATERIAL`
及 `FORMAL_TRAINER_ATTACK_TEXTURES`，且必须是训练假人的独立动画、双 UV 合同与私有图集。
玩家与假人各持同一份自身属性；假人受控范围内的命中走玩家的目标朝向、正式伤害回调
和原 Dmg，不把显示朝向当作背刺依据。此模式固定使用诊断抽样，既不绑定 Unity 的随机流，
也不自动发给玩家技能。玩家生命归零时结束诊断，不替代正式死亡流程。可同时加
`--smoke`，从未改动的出生点验证实际路径进入游走，再向同一个玩家注入方向输入；
另一项追击测试按源验证器摆位后检查原受击与继续追击。二者均不等于 Unity 画面验收。

### 原玩家技能诊断

同时加 `--trainer-diagnostic --player-combat-diagnostic`，从原出生点体验玩家普攻
（`1`）和喷火（`Q` 或 `2`）。两键同时按住时，喷火直到最后一个键松开才收到停止命令。
这是单独启用的切片，不改变普通移动、原假人诊断或默认启动。参数使用
`FORMAL_PLAYER_COMBAT_ANIMATION`、`FORMAL_PLAYER_COMBAT_MATERIAL` 替代上述两个 Dmg 合同：
用锁定的 31629d53 玩家合同提取脚本同时传入 `--include-damage --include-attack`。
`FORMAL_FLAMETHROWER_CUE` 指向私有原喷流 PNG 和 OGG；不接受回退素材。

来源是 `CharacterBase.InitializeAbilities` 和 `CharacterAbilitySet`：一级角色表授予 20001，
预制体追加 20001/20010，成功解析实例后去重填入前两槽，其余槽为空。按键通过原
`InputSystem.OnFireAbility{N}Performed/Canceled` 的命令合同，只派发给当前实际玩家。
`ActiveAbilityBase.ShouldLockTargetDirectionDuringInputGateForRuntime` 的前摇锁与
`CharacterBase.HasFormalActionLock` 的攻击标签分别判定；非静默受击只在安全阶段从
`InterruptActions` 通知实际持有的两项 Timeline，沿各自的 GAS Cancel/End 请求清理。
动作时钟、命中、地表和喷流使用原有实现。测试摆位不是原出生点验收，`--smoke` 仍从
原出生点启动验证玩家技能。此入口不含完整 Action Map/硬件焦点验证、ASC.Cell 指向命令、
手柄、其他技能、完整角色系统和死亡、Unity 原随机流或双端画面对照。

### 原场景的地图登记

原图预览以锁定场景的 `MapInfo` 6951708 持有同一份导航 1148507052，不再以始终为空的
地图提供器接相机。原场景未配置出生检查点、Playtest 检查点、相机覆盖和地图边界；
直接打开它时不合成已加载存档或地图切换事件。实际玩家点击执行从该原地图拥有者解析
导航，保留同一个 649 节点规则图。活动地图登记不搜索场景树，已登记但属于其他场景的
配置不会被采用。范围仅限登记、活动配置解析及其已接入的相机／导航所有权。
不新增地图资产、切换流程、检查点、复活或存档。也不把 `SampleScene` 当作这个地图；
它是另一个已序列化的系统场景，没有这份 `MapInfo`。

### 原主角色持久化身份

锁定 ClickMoveTest 的 PlayerSystem 引用本场景玩家组件 735002000000000004。原主角启动时，
`RegisterCustomInstancedPersistable` 将其预摆标识替换为 `player`，不是追加第二个有效 ID。
Godot 原图预览在同一个实际玩家身上运行这段注册，失去输入不注销，退出该角色才注销。
`player` 属于 PlayerSystem 的角色数据所有权，不进入 PersistenceSystem 自动对象快照。
这仅迁移标识登记与解析；不新增存档文件、不冒充存档、主菜单启动或 SampleScene 验收。

### 原 ClickMoveTest 受伤闪屏

使用 --source-preview --trainer-diagnostic --damage-screen-flash 在同一原图诊断里挂入受伤
闪屏（2110012300）。单加闪屏不额外生成敌人或主动施伤。只监听实际玩家正式扣血后的
完成事件，判断当前受控角色或主角回退；普通红色透明度 0.18，暴击白色 0.30，以非缩放
时间在 0.15 秒内线性消退。闪避、静默、独立的 NoScreenFlash 表现位及其他角色挨打均
不显示；再挨打重新计时，停用清空；覆盖层不挡指针且在原测试面板之下。正式伤害的
表现位只随完成回调，不改变伤害数值、动画准备、命中反应或生命值所有权。
同组参数加 --smoke 会先确认原出生点，再在指定验证站位等待假人 20001 实际命中
同一个玩家、减血并闪现消退。它不是完整全场景的受击表现或 Unity 同帧画面对照；
原场景过渡覆盖层和切换多个真实受控角色尚未接入。

### 暂停和音量设置

锁定 Unity 的 `UIManager.MenuStackRuntime.cs`、`UIManager.MenuRequestRoutingRuntime.cs`、
`GameStateSystem.cs` 和 `InputSystem.cs`：被原角色交互门禁拒绝或面板未挂载时，
不暂停；首层成功挂载才进入 Menu，逐层返回时恢复下层的交互及焦点，最后一层
关闭才回 Gameplay。打开、返回及关闭共用 Escape 和鼠标右键；同一次物理按压不会穿透动作图。
`gameplay_menu_stack.gd` 不加载、拼装或替换面板，只管理宿主显式注入的面板会话；
Godot 同时暂停场景树和缩放时钟，避免以常量源步长运行的固定回调继续推进。
伤害闪屏按原 `DamageScreenFlash.cs` 的非缩放时间继续淡出。已发声的原喷火
GameplaySoundFX 声部也不随菜单停播；原菜单状态没有请求通道暂停，音频仍可由
显式的通道暂停接口独立控制。

`test_gameplay_menu_stack.gd` 使用引擎实际输入、焦点、固定步验证上述合同。
设置私有原图启动资源后，另验证同一原玩家与训练假人冻结，未取消的点击路径恢复，
暂停中的点击不变成玩法命令，真实闪屏仍能结束，已发声的原音轨播放指针继续
推进并自然回收。此项不是声卡录音或原引擎听感验收。该测试注入专用面板，仅验证
生命周期。提供经校验的私有原面板素材之后，正常 F5 入口可打开原暂停根面板
并进入 Settings；作用中的移动和技能输入在切图时通过原命令路径取消。其它子菜单、
菜单音效、对话状态、完整手柄路径和恢复时已按住的方向动作仍未验收。

原暂停菜单字体不借用测试面板的字体。提取器核对原 `RPGSystem SDF` 的材质、
着色器以及 Alpha8 私有字形图集；运行时拒绝不同字节、缺字或不支持的资料。
专用字形绑定分别保留字形的几何宽度、图集取样宽度、基线、字距及 9 像素边界。
面材质仅覆盖原正交等比画布、无轮廓/阴影/发光的分支，未移植完整 TMP。
原生图形验证从 framebuffer 核对单一原字形的取样和透明外部，不是暂停面板
Unity 同帧截图验收。完整原暂停根和 Settings 的录入方式、验证范围见
[设置与音量说明](docs/clickmovetest-settings-audio.md)。

### 主角与活动假人的目标方向提示

原 Unity `31629d53` 的 `0_CharacterActor_Base.prefab`：
`Movement Indicator`（Transform 5011704272699575475）是 `Polydirectional
Pivot` 的子项，读取原 `FollowTargetDirection` 和 `UIMovementIndicator`，不是点击落点标记。
正式 ClickMoveTest 入口将其绑定到同一主角的目标方向通知。保留高 .4 的轴、局部 X=.682、X<=0 反射、
Sprite 顺序 0、原中心 16 PPU、alpha .4509804；方向允许更新时淡入，否则按非缩放时间 ×20 淡出。
不改变静态技能/交互 Pivot，也不提交移动。活动假人同样继承该提示：ClickMoveTest
实例 `735002000000000003` 连接原 `测试-训练假人.prefab` 变体，两级没有移除、
停用或替换该子项；底层 `0_Character_Base.prefab` 的旋转轴是 6935283927959677198，
而 Actor 变体向其添加提示 Transform 5011704272699575475。Godot 将其挂到
实际移动身体，跟随假人自己的目标方向，按已装配的 20001 攻击门控淡出、结束后复原，
不读取主角能力状态。

私有素材单独用 `FORMAL_MOVEMENT_INDICATOR_ATLAS` 指向原 `SPS_GUI.png`，或沿用
`FORMAL_PAUSE_SOURCE/SPS_GUI.png`；不需要打开暂停菜单来显示指示器。未提供素材时不绘制替代图。
运行 `godot --headless --path godot --script tests/test_source_player_movement_indicator.gd`
可在实际入口验证原裁切、方向转换和 Q 技能锁/解锁时的淡出入，不能替代画面对照。
`tests/test_clickmovetest_project_trainer.gd` 走正式入口的真实 AI 攻击，
验证假人箭头随移动原点、攻击淡出、自然结束复原、玩家不受牵连和安全死亡后门控淡出。
这里未覆盖通用眩晕门控、Unity 同序像素或跨引擎死亡表现逐帧对照。
