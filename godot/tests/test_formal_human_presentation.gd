extends SceneTree
const View = preload("res://gameplay/clickmovetest/human_presentation.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var view := View.new()
	root.add_child(view)
	assert(not view.configure({},""))
	var data := {"schema":1,"source_commit":View.SOURCE,"textures":{},"actions":{"Idle":{},"Walk":{}}}
	data.textures = {"x.png":null}
	assert(not view.configure(data,""))
	data.textures = {}
	data.actions.Idle = null
	assert(not view.configure(data,""))
	data.actions.Idle = {"directions":[]}
	assert(not view.configure(data,""))
	assert(view.get_child_count() == 0 and view.sprite == null)
	view.free()
	print("PASS formal Human presentation rejects missing/malformed contracts atomically")
	quit()
