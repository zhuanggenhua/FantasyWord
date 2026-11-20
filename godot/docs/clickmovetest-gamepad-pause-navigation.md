# ClickMoveTest：原 Pause 十字键导航
锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的
`Assets/InputSystem_Actions.inputactions` 中 `UI/Navigate` 为
PassThrough，绑定 `<Gamepad>/dpad`，且不做初始状态检查。Input System
1.18.0 的 `InputSystemUIInputModule` 在更新时使用最新 Navigate 向量，
含回中；斜向等幅选纵向，首个连发等 0.5 秒，后续间隔 0.1 秒。
原根和设置面板保留已迁移的焦点邻接，不为无选中的冷启动指定条目。
进入 UI 前跟踪物理按钮，但不能用按住的键合成切图初始回调；
切图后的真实输入变化使用四键的当前组合。处理本帧移动后才使用
同面板手柄南键的已触发提交，和两个事件的接收先后无关。
独立的 Menu Cancel 路由（East）并未改成延迟提交。
按键盘原路径保持同步；仍活跃的鼠标 Point 按 `InputSystem.cs`
的每帧射线在匹配真实图形时可以重新选中，鼠标移走不清已选焦点。

测试由原项目 F5 入口打开真实 Pause，使用 Godot 视口手柄事件：
预按和回中、正反抵消、斜向、同帧两种南键顺序、到达真实 Settings、
横向、暂停时连发和 East 的逐层退出。独立干净项目没有原私有面板
资源时，只运行 D-pad 合成合同。未验证物理手柄、Unity 实机同帧画面对比、
混合键鼠/手柄控制方案切换、摇杆菜单导航或连续快速关闭重开时 Unity
模块残留导航状态；不要据此认定整个 UI 输入迁移已完成。
