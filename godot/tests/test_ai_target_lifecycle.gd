extends SceneTree
const Lifecycle = preload("res://game_core/ai/ai_target_lifecycle.gd")
var checks := 0
var failures := 0
var attack_attempts: Array = []
var clears := 0
func _initialize(): call_deferred("_run")
func check(ok: bool, detail: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)
func actor(id: String, position := Vector2(2,0)) -> Dictionary:
	return {"id":id,"position":position,"dead":false,"judicious":true,"hostile":true,"visible":true}
func attempt(t: Dictionary, distance: float):
	attack_attempts.append([t.id,distance])
func _run():
	var a = Lifecycle.new()
	a.path_invalidated.connect(func(): clears += 1)
	var hidden = actor("hidden"); hidden.visible = false
	var friendly = actor("friendly"); friendly.hostile = false
	var first = actor("first",Vector2(8,0))
	var nearer = actor("nearer",Vector2(1,0))
	a.tick(0.02,0.02,Vector2.ZERO,Vector2.ZERO,[null,{},hidden,friendly,first,nearer],attempt)
	check(a.target.id == "first","FindTarget uses detection order, not nearest ranking")
	check(attack_attempts.is_empty(),"acquisition tick doesn't attack")
	check(a.target_position == Vector2(8,0),"acquisition tick updates visible destination")
	a.tick(0.02,0.02,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(attack_attempts.size() == 1 and attack_attempts[0] == ["first",8.0],"existing target attacks before movement")
	first.dead = true
	a.waiting_for_attack_facing = true
	a.tick(0.02,0.02,Vector2.ZERO,Vector2.ZERO,[nearer],attempt)
	check(a.target.id == "nearer" and not a.waiting_for_attack_facing,"dead target replaced immediately if cooldown zero")
	check(attack_attempts.size() == 1,"replacement doesn't attack same tick")
	nearer.judicious = false
	a.tick(0.02,0.02,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(a.target.is_empty(),"nonjudicious existing target cleared")
	check(clears == 0,"invalid-target branch does not itself invalidate source path")
	var far = actor("far",Vector2(11,0))
	a.tick(0,0,Vector2.ZERO,Vector2.ZERO,[far],attempt)
	check(a.target.id == "far","acquisition does not add unsourced range filter")
	a.navigation_repath_timer = 2
	a.waiting_for_attack_facing = true
	a.tick(0,0,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(attack_attempts.back() == ["far",11.0],"out-of-range check follows attack callback")
	check(a.target.is_empty() and a.retarget_cooldown == 3,"distance strictly beyond radius stops chase")
	check(clears == 1 and a.navigation_repath_timer == 0 and not a.waiting_for_attack_facing,"stop chase invalidates path/timer/facing")
	check(a.target_position == Vector2.ZERO,"range loss goes home same tick")
	check(not a.try_handle_provoked(first),"provocation blocked by cooldown")
	a.attack_cooldown = 0.25; a.navigation_repath_timer = 0.5
	a.tick(0.25,0,Vector2.ZERO,Vector2.ZERO,[far],attempt)
	check(a.retarget_cooldown == 2.75 and a.attack_cooldown == 0 and a.navigation_repath_timer == 0.25,"three timers use fixed delta with clamp")
	check(a.target.is_empty(),"search not performed during cooldown")
	a.tick(3,0,Vector2.ZERO,Vector2.ZERO,[far],attempt)
	check(a.target.id == "far" and a.retarget_cooldown == 0,"cooldown clamped before search")
	a.target = actor("edge",Vector2(10,0))
	a.tick(0,0,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(not a.target.is_empty(),"exact radius permitted")
	a.target.position = Vector2(12,0)
	a.tick(0,0,Vector2(11,0),Vector2.ZERO,[],attempt)
	check(a.target.is_empty(),"home radius independently drops nearby target")
	a.retarget_cooldown = 0
	var provoker = actor("provoker"); provoker.visible = false; provoker.hostile = false
	check(a.try_handle_provoked(provoker),"provocation only requires judicious, no visibility or hostility")
	check(not a.try_handle_provoked(first),"provocation does not replace existing target")
	a.target = {}; provoker.judicious = false
	check(not a.try_handle_provoked(provoker) and not a.try_handle_provoked({}),"invalid provocation ignored")
	var tracked = actor("tracked",Vector2(4,0))
	a.target = tracked
	a.tick(0,0,Vector2.ZERO,Vector2.ZERO,[],attempt)
	tracked.visible = false; tracked.position = Vector2(5,0)
	a.tick(0.02,1.0,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(a.target_position == Vector2(4,0) and a.time_since_target_last_seen == 1,"unseen target retains last seen, frame delta used")
	a.tick(0.02,2.0,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(not a.target.is_empty() and a.time_since_target_last_seen == 3,"sight timeout is strictly greater")
	a.tick(0.02,0.01,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(a.target.is_empty() and a.retarget_cooldown == 1,"lost sight resets with distinct cooldown")
	check(a.target_position == Vector2(4,0),"sight-loss tick preserves last position, not immediate home")
	a.tick(0.02,0.02,Vector2.ZERO,Vector2(-2,0),[],attempt)
	check(a.target_position == Vector2(-2,0),"next no-target tick uses dynamic home/master")
	tracked.visible = true
	a.target = tracked
	a.tick(0,0,Vector2.ZERO,Vector2.ZERO,[],attempt)
	check(a.time_since_target_last_seen == 0 and a.target_position == Vector2(5,0),"visibility resets memory timer")
	a.retarget_cooldown = 0.1
	var expected = Lifecycle.f32(Lifecycle.f32(0.1)-Lifecycle.f32(0.02))
	a.retarget_cooldown = Lifecycle.f32(0.1)
	a.update_cooldowns(0.02)
	check(a.retarget_cooldown == expected,"cooldown retains Unity float32 arithmetic")
	# FindTarget intentionally accepts hostile/visible even if dead/nonjudicious;
	# rejecting this here would alter the original, despite seeming cleaner.
	a.target = {}; a.retarget_cooldown = 0
	var unusual = actor("unusual"); unusual.dead = true; unusual.judicious = false
	a.tick(0,0,Vector2.ZERO,Vector2.ZERO,[unusual],attempt)
	check(a.target.id == "unusual","FindTarget preserves original predicate, no invented eligibility")
	if failures == 0: print("PASS AI target lifecycle source slice: %d checks" % checks)
	quit(1 if failures else 0)
