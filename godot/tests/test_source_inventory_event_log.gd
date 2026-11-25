extends SceneTree
## 正式 F5 采用同一个队伍库存和原暂停宿主；测试不写玩家文件。
const Money := preload("res://game_core/inventory/source_party_money.gd")
const Bags := preload("res://game_core/inventory/source_inventory_bags.gd")
const Gear := preload("res://game_core/inventory/source_character_equipment.gd")
var _checks := 0
var _failures := 0
var _now := 10.0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var owner:=Money.new()
	var events: Array=[]
	var owner_ref: WeakRef=weakref(owner)
	owner.amount_changed.connect(func(added: bool,amount: int):
		events.append([added,amount,owner_ref.get_ref()._money]))
	owner.add(4)
	owner.remove(9)
	owner.add(0)
	_check(events==[[true,4,4],[false,9,0]] and owner.money()==0,
		"事务量、结算后通知、原下界与非法请求过滤")
	if OS.get_environment("FORMAL_PAUSE_SOURCE").is_empty():
		print("SKIP 正式 F5 事件日志需要锁定私有资源；已执行独立金钱事件检查。")
		_finish()
		return
	root.size=Vector2i(960,540)
	if change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))!=OK:
		quit(1)
		return
	await scene_changed
	await process_frame
	var boot := current_scene
	if not "inventory_event_log" in boot:
		_check(false,"正式 F5 缺失原 Overlay/Event Log")
		_finish()
		return
	var log: Variant=boot.inventory_event_log
	_check(is_instance_valid(log) and log.get_parent()==boot.scene and log.layer>boot.pause_root.layer,
		"正式 F5 在同一 Overlay 以原顺序露出日志")
	if not is_instance_valid(log): _finish(); return
	log.set_process(false)
	log._clock=func(): return _now
	_check(log._rows.size()==5 and log._container.position.is_equal_approx(Vector2(15,80.435))
		and log._container.scale.is_equal_approx(Vector2(.5,.5)) and log._order.is_empty(),"原池 5、左上锚定和空初始")
	var money: Variant = boot.party_money
	money.add(7)
	_check(money.money()==7 and log._rows[0].full=="+7 [INVALID_SHORTNAME]"
		and log._rows[0].shown=="+" and log._rows[0].art.self_modulate.is_equal_approx(Color(1,215.0/255,0)),
		"实际增加事件使用原文本模板、源无效术语、金色和立即首字")
	_now+=.026
	log._tick(_now)
	_check(log._rows[0].shown=="+7","单次等待后只前进一个非空格字符")
	_now+=.026
	log._tick(_now)
	_check(log._rows[0].shown=="+7 [","空白不额外等待")
	money.remove(20)
	_check(money.money()==0 and log._rows[1].full=="-20 [INVALID_SHORTNAME]"
		and log._rows[1].art.position.y>log._rows[0].art.position.y,
		"超额扣款夹到零但按源请求额记录，最新日志排在下方")
	money.add(0)
	money.remove(-1)
	_check(log._order==[0,1] and money.money()==0,"非法数量不假造金钱事件")
	for amount in [2,3,4,5,6]: money.add(amount)
	_check(log._order==[1,2,3,4,0] and log._rows[0].full=="+6 [INVALID_SHORTNAME]"
		and log._rows[0].shown=="+","满池固定复用数组 0，并重置旧打字与图形顺序")
	_escape()
	_check(paused and Engine.time_scale==0.0,"同一项目的原 Esc 确实打开暂停")
	for i in 24:
		_now+=.026
		log._tick(_now)
	_check(log._rows[0].shown=="+6 [INVALID_SHORTNAME]" and log._rows[0].art.mouse_filter==Control.MOUSE_FILTER_IGNORE,
		"零缩放时仍按真实时钟输入更新，原日志文字不拦截指针")
	_now+=3.1
	log._tick(_now)
	_check(log._order.is_empty() and not log._rows[0].art.visible and log._rows[0].shown=="",
		"非缩放停留结束自动隐藏并清空文字")
	log.hide()
	money.add(1)
	_check(log._order.is_empty(),"隐藏即退订，不缓存不可见时发生的事件")
	log.show()
	money.add(1)
	_check(log._order==[0] and money.amount_changed.get_connections().size()==1,
		"重新显示只订阅一次并从空行开始")
	_escape()
	_check(not paused,"恢复不被日志层拦截")
	var bags: Bags=boot.inventory_bags
	var item_layout := OS.get_environment("FORMAL_PAUSE_SOURCE").path_join("item-details-layout.json")
	if FileAccess.file_exists(item_layout):
		_test_items(boot,log,bags,money)
	var prior_log: WeakRef=weakref(log)
	var startup_path: String=ProjectSettings.get_setting("application/run/main_scene")
	if change_scene_to_file(startup_path)!=OK:
		_check(false,"实际 F5 会话重开")
		_finish()
		return
	await scene_changed
	await process_frame
	_check(prior_log.get_ref()==null and money.amount_changed.get_connections().is_empty()
		and bags.item_added.get_connections().is_empty() and bags.item_removed.get_connections().is_empty()
		and current_scene.inventory_event_log._order.is_empty(),
		"释放真实场景时退订旧对象，新的会话不继承旧日志")
	_finish()

func _test_items(boot: Node, log: Node, bags: Bags, money: Money) -> void:
	log.hide()
	log.show()
	var gear: Gear=boot.player.source_equipment()
	var cloth: Resource=gear.item_for_guid(Gear.CLOTH)
	var spear: Resource=gear.item_for_guid(Gear.SPEAR)
	var character: String=boot.primary_bag_owner(boot.player.get_current_controlled_character_or_player_instance())
	var party := bags.party_owner()
	var corpse := bags.corpse_owner("test")
	bags.add(corpse,cloth,2,Bags.Transfer.CHEST)
	bags.add(character,spear,3,Bags.Transfer.EQUIPMENT)
	bags.add(character,spear,1,Bags.Transfer.CORPSE)
	bags.add(party,Resource.new(),1,Bags.Transfer.CHEST)
	_check(log._order.is_empty(),"尸体、装备/尸体转移以及未绑定资源不触发原物品日志")
	bags.add(character,cloth,12,Bags.Transfer.CHEST)
	bags.add(party,spear,1,Bags.Transfer.CHARACTER_DROP)
	bags.remove(character,cloth,22,Bags.Transfer.COMMAND)
	money.add(5)
	_check(log._order==[0,1,2,3] and log._rows[0].full=="+12 基础布衣"
		and log._rows[1].full=="+1 长矛" and log._rows[2].full=="-12 基础布衣"
		and log._rows[3].full=="+5 [INVALID_SHORTNAME]",
		"真实角色/队伍库存用原 Chest/CharacterDrop/Command、白色物品文案和实际移除量")
	_check(log._rows[0].shown=="+" and log._rows[0].item_text.visible
		and log._rows[0].art.self_modulate==Color.WHITE and not log._rows[3].item_text.visible,
		"同一原池区分白色物品字形和金色金钱，不等待首字")
	var before: float=log._rows[3].art.position.y
	for i in 11:
		_now+=.026
		log._tick(_now)
	var layout: Dictionary=log._rows[0].item_text._line
	_check(log._rows[0].shown=="+12 基础布衣" and layout.text=="+12 基础布衣"
		and layout.glyphs.filter(func(glyph): return glyph.silver).size()==4
		and log._rows[3].art.position.y>before,"原 RPGSystem 与 Silver 字形逐字显示且按可见行高度重排")
	log.hide()
	bags.add(character,cloth,1,Bags.Transfer.COMMAND)
	_check(log._order.is_empty() and bags.item_added.get_connections().is_empty()
		and bags.item_removed.get_connections().is_empty(),"隐藏同步退订两种真实物品事件")
	log.show()
	bags.add(character,cloth,1,Bags.Transfer.COMMAND)
	bags.add(character,cloth,2,Bags.Transfer.COMMAND)
	for amount in [2,3,4,5]: money.add(amount)
	_check(log._order==[1,2,3,4,0] and log._rows[0].full=="+5 [INVALID_SHORTNAME]"
		and not log._rows[0].item_text.visible and bags.item_added.get_connections().size()==1,
		"同一行池可从物品换回金钱，不残留白字或重复订阅")
	bags.add(character,cloth,7,Bags.Transfer.CHEST)
	_check(log._order==[1,2,3,4,0] and log._rows[0].full=="+7 基础布衣"
		and log._rows[0].item_text.visible and log._rows[0].shown=="+"
		and log._rows[1].full=="+2 基础布衣",
		"连续第六、七项都覆盖池索引 0；第 2 项未被 FIFO 错删")

func _escape() -> void:
	for down in [true,false]:
		var e:=InputEventKey.new()
		e.physical_keycode=KEY_ESCAPE
		e.pressed=down
		root.push_input(e,true)

func _check(ok: bool,label: String) -> void:
	_checks+=1
	if not ok:
		_failures+=1
		printerr("FAIL ",label)

func _finish() -> void:
	print("%s 原 Overlay 库存日志：%d/%d"%["PASS" if _failures==0 else "FAIL",_checks-_failures,_checks])
	quit(int(_failures!=0))
