extends RefCounted
## Catalog records for an independent equipment demo. Presentation remains on the frame owner.
const SlotIcon = preload("res://gameplay/equipment_workbench/slot_icon.gd")
const SOURCE_MANIFEST_SHA := "572d201e1dc668a595935086b54c8e1b7afc62a69e65dc3282dc6771b0e47997"
const CATEGORIES := {5: "头盔", 6: "帽子", 7: "面罩"}
const STATS := ["体质", "生命", "力量", "智力", "魔力"]
const BUTTON_NAMES := {"角饰头盔":"EquipHornedHelmet", "铁盔 I":"EquipIronHelmetI",
	"铁盔 II":"EquipIronHelmetII", "轻帽":"EquipLightHat", "护目镜":"EquipGoggles"}

var options: Array[Dictionary] = []
var equipped := -1

func load_source(directory: String) -> bool:
	var path := directory.path_join("headwear.json")
	# Pin the reproducible extractor's contract, including GUIDs, bounds, flags and actual SHA values.
	if FileAccess.get_sha256(path) != SOURCE_MANIFEST_SHA:
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var maps := {}
	for guid in data.textures:
		var record: Dictionary = data.textures[guid]
		var filename := directory.path_join(record.file)
		var image := Image.new()
		if FileAccess.get_sha256(filename) != record.sha256 or image.load(filename) != OK or image.get_size() != Vector2i(record.size[0], record.size[1]):
			return false
		maps[guid] = ImageTexture.create_from_image(image)
	for option: Dictionary in data.options:
		var sides: Array[Dictionary] = []
		var icon: ImageTexture
		for row: Dictionary in option.directions:
			var tex: ImageTexture = maps[row.texture]
			var size := tex.get_size()
			var box := Rect2i(int(row.rect[0]), int(row.rect[1]), int(row.rect[2]), int(row.rect[3]))
			sides.append({"map":tex,"rect":Vector4(box.position.x / size.x, box.position.y / size.y,
				box.end.x / size.x, box.end.y / size.y)})
			if icon == null:
				var src := Rect2i(box.position.x, int(size.y) - box.end.y, box.size.x, box.size.y)
				icon = SlotIcon.from_sprite(tex.get_image().get_region(src))
		var channel := "mask" if int(option.type) == 7 else "helmet"
		options.append({"name":option.name,"guid":option.guid,"type":int(option.type),"icon":icon,"stats":option.stats,
			"render":{"channel":channel,"directions":sides,"hide_hair":option.hide_hair,"hide_beard":option.hide_beard}})
	return true

func ids_for(category: int) -> Array[int]:
	var result: Array[int] = []
	for index in options.size():
		if options[index].type == category: result.append(index)
	return result

func equipped_in(category: int) -> int:
	return equipped if equipped >= 0 and options[equipped].type == category else -1

func select_option(index: int) -> void:
	equipped = index

func unequip(category: int) -> void:
	# The source Remove button affects only the current category, not any worn headwear.
	if equipped_in(category) >= 0: equipped = -1

func render_entry() -> Dictionary:
	return {} if equipped < 0 else options[equipped].render

func details(category: int) -> String:
	var title: String = CATEGORIES[category]
	if equipped_in(category) < 0: return title + "\n当前为空"
	var option := options[equipped]
	var text: Array[String] = [option.name, title]
	for row in option.stats: text.append("%s %+d" % [STATS[int(row.stat)],int(row.value)])
	return "\n".join(text)
