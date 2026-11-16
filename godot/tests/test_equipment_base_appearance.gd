extends SceneTree
const Appearance = preload("res://gameplay/presentation/equipment_base_appearance.gd")
var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(detail)

func _initialize() -> void:
	# 仅测试引用身份，不是生产素材，不输出任何验收截图。
	var textures := []
	for i in range(6):
		textures.append(ImageTexture.create_from_image(Image.create_empty(i + 1, 1, false, Image.FORMAT_RGBA8)))
	var appearance := {"left_eye_color":Color(0.2,0.4,0.6), "right_eye_color":Color(0.8,0.3,0.1),
		"hair":{"se":textures[0],"sw":textures[1],"ne":textures[2],"nw":textures[3]},
		"beard":{"se":textures[1],"sw":textures[0]},
		"eye_decoration_east":textures[4], "eye_decoration_west":textures[5]}
	for torso in range(4):
		for head in range(4):
			var frame := {"body_regions":{"torso":{"sprite_facing":torso},"head":{"sprite_facing":head}}}
			var result := Appearance.resolve(3,frame,appearance)
			check(result.body_in_front == (torso >= 2), "身体前后只看躯干")
			check(result.body_in_east == (torso == 0 or torso == 2), "身体东西只看躯干")
			check(result.hair == textures[head], "头发跟随头，不跟随躯干或行")
			check(result.enable_left_eye == (head < 2) and result.enable_right_eye == (head < 2), "眼睛只看头的正背")
			check(result.eye_decoration == (textures[head + 4] if head < 2 else null), "眼饰仅取头的东西正面")
	for left in [false,true]:
		for right in [false,true]:
			var result := Appearance.resolve(0,{"left_eye_closed":left,"right_eye_closed":right},appearance)
			check(result.enable_left_eye == not left and result.enable_right_eye == not right, "左右闭合互不影响")
			check(result.eye_decoration == textures[4], "闭眼不关眼饰")
			check(result.left_eye_color == appearance.left_eye_color and result.right_eye_color == appearance.right_eye_color, "左右颜色仍原样绑定")
	var back := Appearance.resolve(3,{},appearance)
	check(back.body_in_front and not back.body_in_east and back.hair == textures[3], "缺部位回退当前动画行")
	check(back.beard == textures[0], "NW 缺图先 SW")
	check(Appearance.directional_sprite(2,appearance.beard) == textures[1], "NE 缺图回 SE")
	check(Appearance.directional_sprite(3,{"se":textures[1]}) == textures[1], "NW 与 SW 都缺回 SE")
	check(Appearance.directional_sprite(1,{"se":textures[1]}) == textures[1], "SW 缺图回 SE")
	var invalid := Appearance.resolve(7,{},appearance)
	check(not invalid.body_in_front and invalid.body_in_east, "非法躯干行只校正身体为 SE")
	check(not invalid.enable_left_eye and invalid.eye_decoration == null and invalid.hair == textures[0], "非法头朝向眼睛背面而头发回 SE")
	var hidden := Appearance.resolve(0,{},appearance,{"hide_hair":true,"hide_beard":true})
	check(hidden.hair == null and hidden.beard == null and hidden.enable_left_eye, "头部装备分别隐藏头发胡须，不隐藏眼睛")
	appearance.hair = {"nw":textures[3]}
	check(Appearance.resolve(3,{},appearance).hair == null, "缺 SE 即使 NW 有图也禁用头发")
	appearance.erase("eye_decoration_west")
	check(Appearance.resolve(1,{},appearance).eye_decoration == null, "西向眼饰缺失不回退东向")
	var absent := Appearance.resolve(0,{},null)
	check(not absent.appearance_applied and not absent.has("left_eye_color"), "无外观不伪造颜色")
	if failures == 0:
		print("PASS equipment_base_appearance %d checks" % checks)
	quit(0 if failures == 0 else 1)
