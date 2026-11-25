extends SceneTree
const Boot := preload("res://gameplay/clickmovetest/source_startup.gd")
const RESTORE := "restore_source_primary_ability_runtime"
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func key(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=KEY_1
	event.physical_keycode=KEY_1
	event.pressed=down
	root.push_input(event,true)

func run() -> void:
	if OS.get_environment("FORMAL_SURFACE_RULES").is_empty():
		print("SKIP 正式 F5 能力恢复需要锁定关卡私有素材")
		quit()
		return
	check(change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))==OK,"正式 F5")
	await scene_changed
	await process_frame
	var boot := current_scene as Boot
	check(boot!=null and boot.scene!=null and boot.player!=null,"使用正式场景和主角")
	if failures: finish(); return
	check(boot.has_method(RESTORE),"正式入口暴露受限能力恢复")
	if failures: finish(); return
	var block: Dictionary = boot.capture_source_primary_ability_runtime()
	check(block.abilityRuntimeStates.size()==2,"采集实际两个正式能力")
	boot.scene.training_target.ai_controller.stop()
	var host: Node = boot.scene._charged_actor_runtime
	var basic: Node = host.resolve(20001)
	var fire: Node = host.resolve(20010)
	var counts := [0,0]
	var changed := func(_state): counts[0]+=1
	var stopped := func(): counts[1]+=1
	basic.gate.state_changed.connect(changed)
	basic.gate.sequence_stopped.connect(stopped)
	key(true)
	for i in range(24):
		await physics_frame
		if basic.spec.active: break
	check(basic.spec.active and not basic.gate._trigger_released,"真实普通攻击，按住键仍锁住下一次起手")
	check(not boot.call(RESTORE,block) and basic.spec.active,"拒绝中途输入恢复且不终止当前攻击")
	for i in range(90):
		await physics_frame
		if host.is_idle_for_living_save_restore(): break
	check(host.is_idle_for_living_save_restore() and not basic.gate._trigger_released,
		"攻击自然结束后回到空闲，但未松开的 SemiAuto latch 仍在")
	var original_counts: Array = counts.duplicate()
	var bad := block.duplicate(true)
	bad.abilityRuntimeStates[1].inputGate.currentAmmoLoaded=1
	check(not boot.call(RESTORE,bad) and not basic.gate._trigger_released and counts==original_counts,
		"第二行非法时不先重置第一行")
	bad=block.duplicate(true)
	bad.abilityRuntimeStates[1].formalGasAbilityCode=20001
	check(not boot.call(RESTORE,bad) and not basic.gate._trigger_released,"重复能力不是完整持有表")
	bad=block.duplicate(true)
	bad.abilityRuntimeStates[0].state=0
	check(not boot.call(RESTORE,bad) and not basic.gate._trigger_released,"拒绝把 Active 或未迁移能力状态当作冷档")
	bad=block.duplicate(true)
	bad.abilityRuntimeStates[0].extraRuntimeState={"unknown":1}
	check(not boot.call(RESTORE,bad) and not basic.gate._trigger_released,"拒绝无法恢复的附带状态")
	fire.context._character=RefCounted.new()
	check(not boot.call(RESTORE,block) and not basic.gate._trigger_released,"同代码外来实例不能部分恢复")
	fire.context._character=boot.player
	var releases := [0]
	basic.context._completion=func(): releases[0]+=1
	bad=block.duplicate(true)
	bad.abilityRuntimeStates.reverse()
	check(boot.player.set_current_controlled(false) and boot.call(RESTORE,bad) and basic.gate._trigger_released,"按原编号恢复，释放空闲门控的旧按键锁")
	check(basic.context._completion==null and releases[0]==0 and counts==original_counts,
		"静默清除旧回调，不当作自然结束、松手或新技能发出")
	check(host.resolve(20001)==basic and host.resolve(20010)==fire
		and boot.capture_source_primary_ability_runtime()==block,"保持同一实际实例与槽数据")
	key(false)
	check(boot.player.set_current_controlled(true),"恢复操作权限以复测真实热键")
	key(true)
	for i in range(24):
		await physics_frame
		if basic.spec.active: break
	check(basic.spec.active,"同一能力在新起手时仍可通过真实热键执行")
	var actor: Node2D=boot.scene.actor
	boot.persistables.unregister(actor)
	check(not boot.call(RESTORE,block),"拒绝缺失持久身份")
	key(false)
	basic.gate.state_changed.disconnect(changed)
	basic.gate.sequence_stopped.disconnect(stopped)
	finish()

func finish() -> void:
	print("%s 正式 F5 主角能力局部恢复：%d/%d"%["FAIL" if failures else "PASS",checks-failures,checks])
	quit(1 if failures else 0)
