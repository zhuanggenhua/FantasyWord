extends RefCounted
## Character's authored 17 always-interactable targets (eight pairs + Apply).
## Eligibility for an attribute change belongs to UICharacter's state, not
## Button.interactable. Positions supplied in the authored layout group space.
const ActorState := preload("res://game_core/ui/source_character_panel_state.gd")
const APPLY := 17
var _actor_state: ActorState
var _targets: Array[Rect2] = []
var _selected := 0
var _hovered := 0
var _pressed := 0
var _active := false

func bind(layout: Dictionary, actor_state: ActorState) -> bool:
	var default: Variant = layout.get("default_focus")
	if _actor_state!=null or actor_state==null or not default is Dictionary \
			or default.get("stat")!=0 or default.get("button")!="decrease":
		return false
	var rows: Variant = layout.get("rows")
	var apply: Variant = layout.get("apply")
	if not rows is Array or rows.size()!=ActorState.ROWS.size() or not apply is Dictionary: return false
	var targets: Array[Rect2] = []
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if not row is Dictionary or row.get("stat")!=i: return false
		for key in ["decrease","increase"]:
			var part: Variant = row.get(key)
			if not part is Dictionary: return false
			var box := _rect(part.get("rect"))
			if box.size!=Vector2(64,64): return false
			targets.append(box)
	var apply_box := _rect(apply.get("rect"))
	if apply_box.size!=Vector2(448,112): return false
	targets.append(apply_box)
	_targets=targets
	_actor_state=actor_state
	return true

static func _rect(raw: Variant) -> Rect2:
	if not raw is Array or raw.size()!=4: return Rect2()
	for part in raw:
		if typeof(part) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(part): return Rect2()
	return Rect2(raw[0],raw[1],raw[2],raw[3])

func set_active(value: bool) -> void:
	_active=value and _actor_state!=null
	_selected=0
	_hovered=0
	_pressed=0

func focus_default() -> bool:
	if not _active: return false
	_selected=1
	return true

func selected_action() -> int: return _selected

func hit(point: Vector2, offset: Vector2 = Vector2.ZERO) -> int:
	if not _active or not point.is_finite() or not offset.is_finite(): return 0
	for i in range(_targets.size()-1,-1,-1):
		if _targets[i].has_point(point-offset): return i+1
	return 0

func sample_point(hover: int, point_hit: int, point_active: bool) -> void:
	if not _active: return
	_hovered=hover if _valid(hover) else 0
	if point_active and _valid(point_hit): _selected=point_hit

func pointer_down(action: int) -> void:
	if not _active: return
	if _valid(action): _selected=action
	set_pressed(action)

func pointer_release(action: int) -> int:
	var prev := _pressed
	set_pressed(0)
	return prev if _active and prev==action else 0

func set_pressed(action: int) -> void:
	_pressed=action if _active and _valid(action) else 0

func visual(action: int) -> String:
	if not _active or not _valid(action): return "normal"
	if _pressed==action: return "pressed"
	if _selected==action: return "selected"
	if _hovered==action: return "highlighted"
	return "normal"

func move(direction: Vector2i) -> bool:
	if not _active or not _valid(_selected) or absi(direction.x)+absi(direction.y)!=1: return false
	var v := Vector2(direction.x,direction.y)
	var origin := _targets[_selected-1]
	var start := origin.get_center()+origin.size*v/2.
	# uGUI Selectable.FindSelectable Automatic with non-wrapping navigation:
	# from the source-facing rect edge to the candidate center; maximize
	# dot(delta, direction) / squared distance and ignore behind candidates.
	var best := 0
	var best_score := 0.0
	for i in range(_targets.size()):
		if i==_selected-1: continue
		var delta := _targets[i].get_center()-start
		var dot := v.dot(delta)
		if dot<=0.0: continue
		var score := dot/delta.length_squared()
		if score>best_score:
			best=i+1
			best_score=score
	if best==0: return false
	_selected=best
	return true

func activate(action: int) -> bool:
	if not _active or not _valid(action): return false
	if action==APPLY: return _actor_state.apply()
	var stat := (action-1)>>1
	return _actor_state.remove_point(stat) if action%2==1 else _actor_state.add_point(stat)

func _valid(action: int) -> bool: return action>=1 and action<=_targets.size()
