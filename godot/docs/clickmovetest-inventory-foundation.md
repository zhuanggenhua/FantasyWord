# ClickMoveTest：原角色背包的运行时与布局基线

- 源依据：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`，`PlayerSystem`、`CharacterInventory`、`InventorySystem`、`UIInventory`、`UIInventoryBag` 与原嵌套预制体。正常 ClickMoveTest 启动建立一份空库存，以实际玩家持久 ID `Character:player` 查询；不是场景 UUID，不读队伍货币，不把初始长矛或布衣放进背包。
- 数据层按实物资源身份计数，增减事件保留原转移类型和实际增减量。用独立快照填格，不按名称排序。条目移除后允许重用已空的枚举位置；尚未在 Unity 编辑器实机逐序重放删插。30 格是当前分类的展示上限，不限制库存。
- 面板数据层打开重置 Consumable，焦点位于首格。切换分类先清除旧详情，再刷新格子；选中不会使用物品，空格没有使用请求。非空格的模型交给接收端原 actor、同一 target 和 Bag 位置；可见面板目前只接纳已锁定的长矛、基础布衣及空背包；没有接入 Item.Use、物品使用锁或存档。
- `tools/extract_clickmovetest_inventory_layout.py --repo <锁定 Unity Git 树> --out <私有输出>` 复算继承布局、图集引用、分类文字、装备栏、摘要行、焦点框。输出不入库。1920×1080 下首格 (968.5,340) 96×96，6×5、间距 8；四个分类按钮各 188×72 且重叠 24，五个装备格区分从背包中取出的物品，八行摘要按内容尺寸运算。
- 正常启动后的 Pause → Items 已打开注册的 Inventory 子面板：原 30 格、初始长矛与布衣原图标、五个装备位、八项当前有效属性、分类键鼠切换、空格首焦点及 Esc / 右键返回。首个真实演员的满生命/法力不是当前血条读数；初始装备零属性加成。
- 分类术语数据缺项时沿用源 `[INVALID_SHORTNAME]` 及 null sprite 白方块，分类 TMP 不换行且允许溢出，属性名保留原省略设置。未改词、未补图。根据合同校验原 RPGSystem 字形图、Silver 回退、原 GUI 图集及初始装备两张 PNG，资源仅在私有 `FORMAL_PAUSE_SOURCE`，生成布局和 PNG 不入仓。
- 背包服务复用原主角的装备槽真相：`InventorySystem.cs:499–555` 先校验 ChangeEquipment 与库存，角色组件再校验资源下限、设置槽位且发一次变化通知，最后才扣来源包或回指定包。空槽卸下不会增包。同一原资源的替换先扣一件再把旧件归还同一个来源包；无效 owner 显式返回错误而不是抛 C# 异常，不改槽位。
- 原初始装备按继承资产的布衣、长矛顺序绑定；两件装备均无属性差量、附加技能或点击使用效果。复进原 Pause → Items 时，装备栏、背包格、数量和焦点详情都由当前角色和同一物品身份驱动。没有把确认按钮改成穿脱，没有添加当前 Unity 数据不存在的效果。类别仍默认 Consumable。
- 运行 `godot --headless --path godot --script res://tests/test_source_inventory_bags.gd`、`res://tests/test_source_inventory_entry.gd` 和 `res://tests/test_source_equipment_transaction.gd`。无私有合同的运行明确跳过实景入口检查。云桌面可验证原生渲染、来源图标与菜单交互，不等同对照 Unity 截图。
- 设置私有 `FORMAL_PLAYER_CLOTH_PNG` 后，正常 ClickMoveTest 启动将主角的同一装备槽绑定到原人形材质。源 `0_CharacterActor_Base.prefab` 的 `CharacterEquipmentPresentation` 在启用和装备变化时刷新；原基础布衣引用一个 Clothing 表现资产，四方向都用同一 32×32 Sprite，无变体。只接入该槽和该原图，不从独立换装工作台读状态。未提供原图时保留既有启动方式，提供不匹配的原图时拒绝该装配。
- `tests/test_source_cloth_presentation.gd` 在真实 Entry 演员、装备及背包服务上运行，`FORMAL_CLOTH_TEST_CONTRACTS` 指向已抽取的原站立动画和材质合同（`animation.json`、`material.json`），`FORMAL_PLAYER_TEXTURES` 指向对应图集、UV 与外观目录。Godot 原生窗口在同一待机帧取样验证卸下确实改变像素、重新穿上完全恢复；装备锁不改画面、行走切换不重设布衣。该测试不装配完整 F5 场景，也未做 Unity 同屏比对。
- **不是完整 Inventory 或换装表现**：已接两件原始零加成装备的事务与菜单投影，以及原基础布衣的材质联动。长矛角色外观、其他装备、附加属性/技能、叠加锁、物品使用及其对白、掉落、存档、坐骑、外部 HUD、手柄全局导航和 Unity 像素比对未验收。测试由服务发起装备变化，不是新增玩家换装交互。
