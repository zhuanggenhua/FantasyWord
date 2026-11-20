extends SceneTree
const Text := preload("res://gameplay/clickmovetest/source_character_text.gd")
const Atlas := preload("res://gameplay/clickmovetest/source_menu_glyph_atlas.gd")
var count := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	count+=1
	if not ok:
		failures+=1
		printerr("FAIL ",label)

func _initialize() -> void:
	var p := OS.get_environment("FORMAL_PAUSE_SOURCE")
	if p.is_empty():
		print("SKIP UICharacter text needs the authenticated private materials")
		quit(0)
		return
	var pause: Variant = JSON.parse_string(FileAccess.get_file_as_string(p.path_join("pause-contract.json")))
	var atlas := Atlas.new()
	var silver := Text.load_silver(OS.get_environment("FORMAL_PANEL_SILVER"))
	if not pause is Dictionary or not atlas.bind(pause,p.path_join("pause-font-atlas.bin")) or silver==null:
		printerr("FAIL source atlas and Silver required")
		quit(1)
		return
	var row_box := Rect2(372.5,317,275,64)
	var term_box := Rect2(1163.5,317,240,64)
	var class_box := Rect2(1403.5,317,208,64)
	var apply_box := Rect2(1183.5,721,408,72)
	var opts := {"style":0,"size":64,"horizontal":1,"vertical":512,"overflow":1}
	var stat := Text.layout(atlas,"[INVALID_SHORTNAME]",row_box,opts)
	check(stat.get("text")=="[INVALID_…" and stat.baseline==Vector2(372.5,367)
		and is_equal_approx(stat.width,255.88772),"stat fallback fit and static line baseline")
	for term in ["[INVALID_SHORTNAME]","[INVALID_SHORTNAME] Req.","[INVALID_FULLNAME]"]:
		var line := Text.layout(atlas,term,term_box,opts)
		check(line.get("text")=="[INVALID…" and line.baseline==Vector2(1163.5,367)
			and line.glyphs.back().silver,"info fallback fits before one dynamic ellipsis")
	opts.horizontal=2
	var actor := Text.layout(atlas,"玩家角色配置",class_box,opts)
	check(actor.get("text")=="" and actor.glyphs.is_empty(),"class full-height Silver overflows before a visible candidate")
	opts.size=48
	opts.overflow=0
	var apply := Text.layout(atlas,"应用 0 点",apply_box,opts)
	check(apply.get("text")=="应用 0 点" and apply.glyphs.size()==6
		and is_equal_approx(apply.baseline.y,763.6315789),"Apply preserves mixed line baseline")
	if not apply.is_empty():
		check(apply.glyphs[0].silver and apply.glyphs[1].silver and not apply.glyphs[2].silver
			and not apply.glyphs[3].silver and not apply.glyphs[4].silver and apply.glyphs[5].silver,
			"Apply resolves digit/space to original static owner and CJK to exact Silver")
	var view := Text.new()
	root.add_child(view)
	check(view.configure(atlas,silver,"应用 0 点",apply_box,opts,.5),"mixed renderer binds both authenticated owners")
	print("%s UICharacter text: %d/%d"%["PASS" if failures==0 else "FAIL",count-failures,count])
	quit(1 if failures else 0)
