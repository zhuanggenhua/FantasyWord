# ClickMoveTest 的原交互入口

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。原输入资产的
`Gameplay/Interact` 和 `UI/Submit` 共用 F、Enter、Space 和手柄南键。
`InputSystem.OnInteractPerformed` 检查动作图松键门禁后提交交互命令；
`CharacterCommandExecutor` 仍检查角色资格，原 `CharacterButtonActivation`
从同一 Static Pivot 检测距离 0.75、Interaction 层及角色朝向，动作每次重新解析。

原 ClickMoveTest 场景的两个实例是原主角与训练假人；沿场景及其嵌套角色
Prefab 检查，没有 Interaction 层的场景目标。命令实际找不到接收者而返回
BlockedByState，`UIHUDAbilityMessage` 显示「没有可交互对象。」；没有当前输入
目标则显示「当前没有可控制角色。」。正式 Godot 开局装配同一个输入目标、
命令宿主、Static Pivot 和真实物理查找，不添加假 NPC、宝箱、成功音或伪造交互。
原交互成功将请求频道 2 的 `AUDIO_ISFX_Interact`；此景和本地锁定素材中没有
足以实测这条成功链的目标/声音，本批不宣称已接通或通过。

共享的 Button 只在物理组从零转为按下时提交一次；别名键仍按着、重复键和释放
不重复触发。切入暂停后旧压键不能触发 UI；从 UI 回到 Gameplay 同样等全部松开。
没有按时间猜测或清掉另一层尚按着的键。UI 仍须真实选中按钮才处理 Submit；不替
暂停默认选择、不打开新面板。支持本切片键盘和默认手柄设备 0 的南键事件；
不宣称系统级重映射、多手柄或完整物理手柄验收。失去窗口焦点清空输入样本，
不是已验证 Unity 各平台失焦行为相同。

定向验收 `test_source_interact_entry.gd` 从真实 F5、物理坐标的 Pointer 路由、
Pause/Inventory、实际命令与 HUD 测按键、别名、菜单往返与原生帧显示；硬件
手柄、Unity 画面对照及存档均不在本范围。
