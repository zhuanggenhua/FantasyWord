# ClickMoveTest：原技能菜单与真实快捷栏

原输入和预制体锁定为 Unity `31629d53a110dd4c87d4c85e6ad5a387fbafb931`。正常 F5 启动后的 Pause → Abilities（动作 4）打开 EMenu 2，读的是同一个实际角色已持有的技能和玩法热键所消费的五个槽。开局主动能力为普攻与喷火，被动为空；重开缓存菜单保留上次分类。已装备技能换到另一槽会清空旧槽，清槽不撤销已持有技能。同槽同能力请求成功但不重复通知。

选中主动条目按下选择进入装备模式。有活动 UI Point 时不抢指针焦点；无活动点时选择第一槽。此时显示原箭头及列表遮罩，列表不响应新的选槽起点。返回先取消装备模式，不直接弹菜单。平常点击快捷槽清掉那个槽。实测从正式菜单把普攻移到第五槽，返回玩法后按 5 播放真实 Attack，未创建替代技能或第二份快捷栏。

布局回溯 `UIAbilities.prefab` 的 Base Menu、列表内部布局、两个分类控件和五个继承的 Ability 槽。1920×1080 时内容 [343,256,1234,688]，左侧外层 VLG 间距 64（分类内部才是 8），原裁剪框 [388,461,454,438]，右侧说明 [969,352,576,432]，首槽 [985,832,96,96]。源主动/被动分类术语表未填，继续用原缺项文案和 null sprite 白图块；没有把其翻译成臆造分类标签。普攻用源 SpriteReference 解析到原图，喷火的有效技能图标为空，与真正空槽区分。说明按原时间线的伤害条目逐个生成，普攻两条、喷火十四条，保留原重复项、下划线及说明区包裹与省略。混合字形保留原 RPGSystem 图集和已核 Silver 字体尺寸依据，不宣称 TMP 字距、回退字形和换行达到 Unity 像素一致。

`tools/extract_clickmovetest_abilities.py --repo <锁定 Unity Git 树> --attack-image <验证后原始 PNG> --silver <原 Silver.ttf> --out <私有输出>`（PyYAML、fontTools）复算布局、作者术语及时间轴数据。将生成合同与已核原图作为私有 `FORMAL_PAUSE_SOURCE` 的 `abilities-layout.json` 和 `abilities-attack.png` 输入；禁止将二者或原始素材放入仓库。测试 `test_source_abilities_entry.gd` 与 `test_source_ability_slot_actor.gd` 会标明私有真实入口的跳过。没有验收新获得能力、被动内容、缓存过期、手柄物理按键和设备提示图标、存档以及 Unity 真机像素对照。

## 分类焦点与切换分离

锁定原 `InputSystem.Update` 对主动 UI Point 做射线检测。原 Ability Category 的
Button 和目标 Image 可射线命中，`UIAbilityCategory.OnSelect` 只换说明。移动到
分类上不会切换列表或改写快捷槽；离开按钮后保留已选中的分类，按确认或实际点击才
调用原分类选择回调。已在正式 F5 → Pause → Abilities 验证主动与被动说明，仍未验收
Unity 同帧截图、全局指针射线优先级或原输入模块同帧调度。
