extends RefCounted
## Unity uGUI Button.OnSubmit's temporary SpriteSwap state. The locked Ability
## Category, Inventory Category Entry and Character Apply use the same fade.
const DURATION := 0.1
var pressed := 0
var _generation := 0

func start(action: int, tree: SceneTree, refresh: Callable) -> void:
	if pressed==action: return
	_generation+=1
	var generation := _generation
	pressed=action
	tree.create_timer(DURATION,true,false,true).timeout.connect(func():
		if generation!=_generation: return
		clear()
		if refresh.is_valid(): refresh.call())

func clear() -> void:
	if pressed==0: return
	pressed=0
	_generation+=1

func interrupt_pointer(previous: int, next: int) -> void:
	# Native Selectable pointer enter/exit immediately publishes its state.
	if previous!=next and pressed in [previous,next]: clear()
