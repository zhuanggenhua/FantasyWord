# ClickMoveTest：原角色背包的运行时与布局基线

- 源依据：Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`，`PlayerSystem`、`CharacterInventory`、`InventorySystem`、`UIInventory`、`UIInventoryBag` 与原嵌套预制体。正常 ClickMoveTest 启动建立一份空库存，以实际玩家持久 ID `Character:player` 查询；不是场景 UUID，不读队伍货币，不把初始长矛或布衣放进背包。
- 数据层按实物资源身份计数，增减事件保留原转移类型和实际增减量。用独立快照填格，不按名称排序。条目移除后允许重用已空的枚举位置；尚未在 Unity 编辑器实机逐序重放删插。30 格是当前分类的展示上限，不限制库存。
- 面板数据层打开重置 Consumable，焦点位于首格。切换分类先清除旧详情，再刷新格子；选中不会使用物品，空格没有使用请求。非空格的模型交给接收端原 actor、同一 target 和 Bag 位置；可见面板只接纳确认为空的初次背包，未接入真实 Item.Use、使用锁、装备变更或存档。
- `tools/extract_clickmovetest_inventory_layout.py --repo <锁定 Unity Git 树> --out <私有输出>` 复算继承布局、图集引用、分类文字、装备栏、摘要行、焦点框。输出不入库。1920×1080 下首格 (968.5,340) 96×96，6×5、间距 8；四个分类按钮各 188×72 且重叠 24，五个装备格区分从背包中取出的物品，八行摘要按内容尺寸运算。
- 正常启动后的 Pause → Items 已打开注册的 Inventory 子面板：原 30 格、初始长矛与布衣原图标、五个装备位、八项当前有效属性、分类键鼠切换、空格首焦点及 Esc / 右键返回。首个真实演员的满生命/法力不是当前血条读数；初始装备零属性加成。
- 分类术语数据缺项时沿用源 `[INVALID_SHORTNAME]` 及 null sprite 白方块，分类 TMP 不换行且允许溢出，属性名保留原省略设置。未改词、未补图。根据合同校验原 RPGSystem 字形图、Silver 回退、原 GUI 图集及初始装备两张 PNG，资源仅在私有 `FORMAL_PAUSE_SOURCE`，生成布局和 PNG 不入仓。
- 运行 `godot --headless --path godot --script res://tests/test_source_inventory_bags.gd` 和 `res://tests/test_source_inventory_entry.gd`。无私有合同的运行明确跳过实景入口检查。云桌面可验证原生渲染、来源图标与菜单交互，不等同对照 Unity 截图。
- **不是完整 Inventory**：非空背包真实渲染、选中装备的详情浮层、物品使用/换装/掉落/存档、外部 HUD 与手柄全局导航、Unity 像素比对未验收。
