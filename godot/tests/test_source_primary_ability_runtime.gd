extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const CAPTURE := "capture_source_primary_ability_runtime"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	root.push_input(event,true)

func row(code: int) -> Dictionary:
	return {"formalGasAbilityCode":code,"state":1,"remainingCooldownTimer":0.0,
		"inputGate":{"currentAmmoLoaded":0},"extraRuntimeState":null}

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 原主角能力运行时快照需要锁定关卡私有素材")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	check(boot!=null and boot.scene!=null and boot.player!=null,"正式主角与场景")
	if failures: finish(); return
	var owner = boot.player
	var host: Node = boot.scene._charged_actor_runtime
	check(is_instance_valid(host) and is_instance_valid(host.resolve(20001)) and is_instance_valid(host.resolve(20010)),
		"由正式 F5 装配的两个不同实例")
	check(boot.has_method(CAPTURE),"正式入口有独立快照")
	if failures: finish(); return
	boot.scene.training_target.ai_controller.stop()
	var expected := {"abilityRuntimeStates":[row(20001),row(20010)]}
	var original: Dictionary = boot.call(CAPTURE)
	check(original==expected,"顺序由原等级技能与预制体额外技能决定")
	original.abilityRuntimeStates[0].inputGate.currentAmmoLoaded=101
	check(boot.call(CAPTURE)==expected,"消费者修改旧快照不能污染新快照")
	check(owner.clear_equipped_ability_slot(1) and owner.active_ability_menu_codes()==[20001,20010]
		and boot.call(CAPTURE)==expected,"卸下第二槽不撤销正式实例；能力快照不读快捷槽")
	key(KEY_1,true)
	var basic: Node = host.resolve(20001)
	for i in range(24):
		await physics_frame
		if basic.spec.active: break
	check(basic.spec.active,"通过真实热键进入普攻正式活动执行")
	check(boot.call(CAPTURE)==expected and basic.spec.active,"活动执行仍序列化 Inactive，不取消施法、不写输入状态")
	key(KEY_1,false)
	check(owner.set_current_controlled(false) and boot.call(CAPTURE)==expected,
		"主角能力从主角所有者捕获，不取当前控制角色")
	var fire: Node = host.resolve(20010)
	fire.context._character=RefCounted.new()
	check(boot.call(CAPTURE)=={},"外来实例不接受同一代码冒充")
	fire.context._character=owner
	check(boot.call(CAPTURE)==expected,"恢复真实所属者可再次捕获")
	var actor: Node2D = boot.scene.actor
	boot.persistables.unregister(actor)
	check(boot.call(CAPTURE)=={},"实例仍活跃，但主角身份失去登记时拒绝捕获")
	check(boot.persistables.register_custom_instanced(actor,"player") and boot.call(CAPTURE)==expected,
		"恢复原登记可再次采集两个实例")
	fire.queue_free()
	check(boot.call(CAPTURE)=={},"待释放实例不能伪装成活实例")
	await process_frame
	check(boot.call(CAPTURE)=={},"主角仍正式登记；缺少实例时不伪造空、部分或默认行")
	finish()

func finish() -> void:
	print("%s 正式 F5 主角能力运行时快照：%d/%d"%["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)
