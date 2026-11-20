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
原子菜单的业务接收器、手柄、暂停/恢复音效、Unity 实机像素对照仍未验收；
不会用示意子菜单替代。现有键鼠路径是限定子集，尚未处理恢复玩法时的
全部原 Initial State Check 或不同绑定组同帧仲裁。

遮罩为原色 RGBA (63,40,50,200)/255，铺满整个实际视口。原 CanvasScaler
匹配高度，左栏保留左边锚点，标题与页脚居中，Effects 贴右。此处不承诺
Unity 画布像素取整和颜色空间合成已完全一致。
