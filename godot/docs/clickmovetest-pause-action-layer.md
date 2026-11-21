# ClickMoveTest 暂停动作图接线

动作图测试使用默认 ClickMoveTest 启动后的真实玩家、地图、能力命令和计时；
注入测试面板只验证动作图切换。另有使用真实 F5 暂停、设置面板的集成测试。

Unity 项目基准 `31629d53a110dd4c87d4c85e6ad5a387fbafb931`：
`InputSystem.cs` 的 `SetActionMap` 先切动作图，再读取目标动作的
`IsPressed()`；`OnMoveCanceled` / `OnFireAbility*Canceled` 按正常角色命令
提交 StopMove / StopFireAbility。对应 Godot 入口在进入暂停前仅取消活跃方向
与活跃槽位；多个物理键映射同一槽时只取消一次。未活跃的方向动作不会
取消既有的点击路径。切换不调用玩家控制开关，不改变角色所有权和输入资格。
Point 在旧层禁用时清空，暂停宿主仅观察 UI Point，返回后不合成新的
Gameplay Point。已停用的玩法路由不再接收物理或外部归一化边沿。

不按物理键直接预挂释放门禁：项目固定 Input System 1.18.0 中，禁用动作
不保留 IsPressed；Value 初始检查在下一次输入更新，非切换同步执行。
UI Navigate、Submit、Cancel、Click 默认无初始检查；Gameplay Move 为 Value
且开启初始检查；FireAbility 为 Button 且不开启。因而真正初始化顺序、
恢复时仍按住方向键的初始检查、同图子菜单独立 Cancel 门禁，以及 UI
导航/鼠标按下及抬起，仍需要分别按来源接入并比较，不能用一个 raw
held 门禁代替。

## 默认 Controls 页脚

锁定的 UI 根对象引用原 UI Controller Button Manager，实例未覆盖其
`m_buttonPromptsVisible=0`。因此默认两个图标 Image 不绘制也不参与射线，
但仍保留布局宽度。两段 RPGSystem SDF 正常字重的白字分别是右对齐
Select 和左对齐 Close，1600 或 1920 等非同参考高度下的屏幕像素对照另验。
参考画布 1920×1080，父组 x=688、宽 544，两个 264 宽的子组在各自
272 宽的弹性单元内居中，子组 x=692、964，而不是把固定宽度内容整体
居中。内组各有 20 间距。文字矩形分别为 (692,996,180,64)、
(1048,996,180,64)，都属于不可选中的射线图形；空位 x=892、964
不拦截。运行时未迁移显式开启图标的设备变体，也没有把文字当作按钮。

## 正常 F5 场景的原暂停根面板实验接线

为原 `godot/project.godot` 运行进程设置 `FORMAL_PAUSE_SOURCE` 指向新
抽取的私有目录（锁定合同、Alpha8 RPGSystem 图集、校验过的 SPS_GUI.png）。
无该目录仍保持此前的游戏启动路径。不得把私有源文件加入 Git。
Esc / 鼠标右键在原角色命令门禁后开启或关闭真实根面板。保持此前点地路径，
左键确实在同一原项目条目按下抬起才发出对应请求，悬停及静止 Point
可选中原项目条目。初次无默认焦点，原 Effects 标题仍可见。活动效果租用、
未接入的原子菜单业务、暂停/恢复音效、Unity 实机像素对照仍未验收；
不会用示意子菜单替代。手柄已接入的范围与混合设备限制见
[原暂停手柄导航](clickmovetest-gamepad-pause-navigation.md)。

遮罩为原色 RGBA (63,40,50,200)/255，铺满整个实际视口。原 CanvasScaler
匹配高度，左栏保留左边锚点，标题与页脚居中，Effects 贴右。此处不承诺
Unity 画布像素取整和颜色空间合成已完全一致。

## 完全关闭和重开时的根菜单焦点

锁定版 `UIManager.MenuStackRuntime.cs` 使用 UIKit 的栈内 Pop 和异步 Open。
`UIRoot.Stack.cs` 的 Pop 直接调用 `UIPanel.Close()`，这一关闭隐藏并
触发回调，不经过另一个会逐出缓存的 ClosePanelInternal；
`UIRoot.PanelOperations.cs` 异步 reopen 可查询并打开同一缓存面板。
`UIGameMenuEntry.OnSelect` 把最近选中项回写给原面板，
`UIGameMenu.ResolveDefaultFocusTarget` 在真正重开时恢复它。

Godot 的原 Pause 根跟随原启动场景生命周期保持同一个实例：
退出时从栈中移除并停止处理、隐藏标签，不能挡住 Gameplay；
重新打开不合成旧输入，但由同一原面板恢复焦点和标签。
切换整张启动场景后首次打开仍没有默认焦点。此处只迁移正常 Pause 根
关闭、再次 Open 的缓存路径，不把其他面板或 UIKit 的全局淘汰策略
认作已迁移。云端原生 F5 使用注入输入覆盖该链，不是 Unity 实机画面对照。

## 主角死亡关闭菜单

锁定版的 `CharacterActor.OnDeath` 调用 `PlayerSystem.NotifyCharacterKilled`。
该路径在执行可选的死亡命令之前请求关闭所有菜单；`ClickMoveTest` 的可选命令为空，
但不跳过菜单请求。`UIManager.OnCloseAllMenusRequested` 逐层调用正常 Pop，
不走返回键和子面板的手动返回门禁。

Godot 在主角已进入安全死亡阶段、尝试锁定原 SpinDie 后，经同一正式菜单栈逐层
关闭，早于装备移交和失控通知。背包子页释放，暂停根保持隐藏缓存，最后一层
只恢复一次 Gameplay 动作图和时钟；尸体不会因此获得控制。未安装菜单的独立
诊断不新增菜单。对话中断和可选死亡命令仍未移植。

菜单集成试验用 `FW_TEST_SOURCE_DEATH_MENU=1` 将已经排队的实际地表伤害与
原 Esc → Items 输入交错，随后推进安全死亡阶段；不是让暂停时的普通玩法继续计时。
未设置该变量时仍验证同一个无菜单原受击流程。Unity 同帧画面对照仍未验收。

## Gameplay 的原菜单命令与失败提示

锁定 `31629d53` 的 InputSystem 回调先确认当前动作图和释放门禁，再通过
`ExecuteLocalPlayerCommand(OpenGameMenu)` 查询当次控制目标。Esc、鼠标右键、
设备 0 的手柄 Start 现在向原角色命令执行者提交同一请求，不由菜单栈直接绕过。
执行者使用原 Interact **动作**门禁，失败为 BlockedByState；它不要求交互接收件，
成功时只请求已注册的原 Pause。UI Cancel 仍只弹当前层，不提交 Gameplay 命令。

未找到当前控制角色时由原 HUD 显示「当前没有可控制角色。」，不暂停、不改动作图、
不借用镜头跟随对象。覆盖真实启动、正常打开、按住交互仍进入 UI、Start/East 分别
负责打开/返回、真实死亡后再按 Esc 的失败；不把阶段性设备注入描述为实体手柄、
全系统配对或 Unity 同画面对照。
