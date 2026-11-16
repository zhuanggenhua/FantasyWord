# CharacterButtonActivation 原生查询切片

锁定 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931` 的
`Assets/Scripts/GameCore/Runtime/Entities/Characters/CharacterButtonActivation.cs`。
配置来自 GameConfig.asset 的 Interaction、TagManager 第 6 号 Unity 层（Godot 掩码 64），Actor prefab 半径 0.75；ClickMoveTest Static Pivot 在 Godot 为 `(0,-0.4)`，不是表现 Body。

新增显式宿主接口，不自行装配正式玩家系统：`configure` 注入原角色门禁、GetTargetDirection 对应方法、真实 pivot 和音效请求回调。`register_collider` 将每个原 Collider2D 的物体原点映射到一个原生 CollisionObject2D，并保留原 offset；宿主负责正确的形状及其变换、组件顺序及 activeInHierarchy。一个物体的多个 Collider2D 应独立映射，不能靠合并形状替代不同 offset。未登记的 Interaction 层命中直接报错，不能悄悄忽略。

实际调用 Godot 圆形空间查询，同时查询 body/area。动态扩大结果上限，防止默认 32 条截断。先按物体原点距离排序，再用原始 offset 和目标方向做严格正 dot 筛选，不旋转/缩放 offset；不因最近目标没有接收者而跳到远目标。等距离排序无跨引擎稳定顺序保证。

接收者由宿主显式按源组件顺序登记，沿父链收集后派发；起点本身始终检查，祖先受 activeInHierarchy 过滤。成功才请求原音效并设置当帧交互闩锁；刷新清闩锁且更新 UI 缓存，真实执行重新查询但不改 UI 缓存；reset 同时清缓存和闩锁。缓存位置是物体原点而非形状中心。

底层显式目标绕过自动搜索和其内部 CanInteractNow 门禁，这不等于命令入口绕过权限。原 CharacterCommandExecutor 另有外部门禁及错误码，本切片不实现 GAS、命令路由、Entity/CommandTrigger 效果。

## 验证边界

`test_character_button_activation.gd` 是独立原生物理测试夹具，非新增原场景内容。覆盖 area/body、掩码、方向/offset、原点排序、缓存、显式目标、全部组件和父链、inactive、闩锁、音效请求、超过 32 命中。
ClickMoveTest 未找到 Interaction 层自动候选，因此不在启动场景伪造目标；原有 Entity receiver 并不意味着它就在自动搜索层。尚未完成正式宿主装配、接收者效果、Unity 与 Godot 同条件截图及完整玩法验收。

## ClickMoveTest 宿主接入

在同一角色的 start_human_logic、start_human_aim 之后，可以显式调用
start_human_interaction(owner, audio_request)。只用该角色实际的 Static Pivot；启用后入口
先刷新缓存，再更新闲置鼠标瞄准，不重复调用外部宿主的刷新。禁用、失去角色控制或停止瞄准时清理
交互缓存与帧内标记。入口不生成碰撞对象或接收组件；锁定的 ClickMoveTest 静态层级实际未发现
Interaction 层自动目标。测试另外建立形状断言次序，不视为正式游戏目标。
