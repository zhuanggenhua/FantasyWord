extends SceneTree
const Cursor = preload("res://game_core/presentation/equipment_frame_cursor.gd")
var count := 0
var failed := 0
var calls := 0
var cursor := Cursor.new()
func check(ok: bool, text: String) -> void:
	count += 1
	if not ok: failed += 1; push_error(text)
func texture(rect: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	var image := Image.create(256,128,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	result.atlas = ImageTexture.create_from_image(image)
	result.region = rect
	return result
func _initialize() -> void:
	cursor.refresh_requested.connect(func(): calls += 1; cursor.refresh_frame())
	var first := {"frame_index":5,"row_index":2,"marker":"first"}
	var duplicate := {"frame_index":5,"row_index":2,"marker":"duplicate"}
	var other := {"frame_index":5,"row_index":3,"marker":"other"}
	var animation := {"frame_size":Vector2i(32,32),"frames":[null,first,duplicate,other]}
	cursor.configure_animation(animation)
	var sprite := texture(Rect2(160,64,32,32))
	cursor.late_sync(sprite)
	check(calls == 1 and cursor.frame_index == 5 and cursor.row_index == 2,"以实际区域列5行2而不是动作标签索引取帧")
	check(is_same(cursor.cached_frame,first),"重复帧键首项获胜，跳过空项")
	cursor.late_sync(sprite)
	check(calls == 1,"相同纹理引用不重刷")
	sprite.region = Rect2(160,96,32,32)
	cursor.late_sync(sprite)
	check(calls == 1 and cursor.row_index == 2,"区域原地编辑不伪造源 Sprite 引用变化")
	cursor.sync_current_sprite(sprite)
	check(calls == 2 and cursor.row_index == 3 and is_same(cursor.cached_frame,other),"显式刷新按当前真实区域重采样")
	cursor.set_preview_direction(100)
	check(calls == 2,"裁剪为相同行不重复刷新")
	cursor.set_preview_direction(-1,false)
	check(calls == 2 and cursor.row_index == 0 and cursor.cached_frame == null,"不同预览方向裁剪、清缓存且可延后刷新")
	cursor.set_preview_direction(2)
	check(calls == 3 and is_same(cursor.cached_frame,first),"不同预览方向刷新当前列")
	var replacement := {"frame_index":5,"row_index":2,"marker":"replacement"}
	animation.frames[1] = replacement
	cursor.refresh_frame()
	check(is_same(cursor.cached_frame,first),"源列表同数量替换不自动重建缓存")
	animation.frames.append({"frame_index":1,"row_index":0})
	cursor.refresh_frame()
	check(is_same(cursor.cached_frame,replacement),"数量变化重建查表")
	cursor.sync_current_sprite(null)
	check(calls == 4 and cursor.last_sprite == sprite and cursor.row_index == 2,"显式空精灵仍刷新但保留采样引用与坐标")
	cursor.late_sync(null)
	check(calls == 4 and cursor.last_sprite == null,"帧更新为空精灵只记录引用不刷新")
	cursor.configure_animation({})
	cursor.late_sync(sprite)
	check(calls == 4 and cursor.row_index == 2,"无动作数据不猜图集")
	cursor.configure_animation({"frame_size":Vector2i(0,32),"frames":[]})
	cursor.sync_current_sprite(sprite)
	check(calls == 4,"非正帧尺寸不刷新")
	cursor.configure_animation(animation)
	var fractional := texture(Rect2(159.5,63.5,32,32))
	cursor.sync_current_sprite(fractional)
	check(cursor.frame_index == 4 and cursor.row_index == 1 and cursor.cached_frame == null,"按 floor 取帧，不四舍五入、不用区域尺寸当步长")
	var second_animation := {"frame_size":Vector2i(32,32),"frames":[first]}
	cursor.configure_animation(second_animation)
	cursor.sync_current_sprite(texture(Rect2(160,64,32,32)))
	check(is_same(cursor.cached_frame,first),"动画资源独立缓存")
	cursor.configure_animation(animation)
	cursor.sync_current_sprite(sprite)
	check(is_same(cursor.cached_frame,other),"回原动作复用对应缓存，不混用新动作列表")
	if failed == 0: print("PASS 装备精灵帧游标：%d 项" % count)
	quit(1 if failed else 0)
