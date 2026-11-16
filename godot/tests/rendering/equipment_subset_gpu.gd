extends SceneTree
## 真正 Godot 渲染设备下的内部辅助验证；测试图不属于正式素材或验收截图。
const Binder = preload("res://gameplay/presentation/equipment_subset_material.gd")
const Mix = preload("res://game_core/presentation/equipment_character_layers.gd")
const Sampler = preload("res://game_core/presentation/equipment_uv_sampler.gd")
var failures := 0
var checks := 0
var layers: Dictionary = {}
var images: Dictionary = {}
var body_rg := Vector2.ZERO
var head_rg := Vector2.ZERO
var rect := Rect2(0.125,0.25,0.5,0.625)
func _initialize() -> void:
	call_deferred("run")
func sample_body(key: StringName) -> Color:
	return Sampler.sample_point(images[key],Sampler.equipment_uv(body_rg,rect))
func sample_head(key: StringName) -> Color:
	return Sampler.sample_point(images[key],Sampler.equipment_uv(head_rg,rect))
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("需要真实 Godot 图形驱动；headless 不能验证着色器像素")
		quit(2)
		return
	var main := Image.create(8,8,false,Image.FORMAT_RGBAF)
	var body := Image.create(8,8,false,Image.FORMAT_RGBAF)
	var head := Image.create(8,8,false,Image.FORMAT_RGBAF)
	var ids := [0.0,0.2,0.3,0.35,0.4,0.5,0.6,0.7]
	for y in 8:
		for x in 8:
			main.set_pixel(x,y,Color(0.2,0.4,0.6,1.0 if y%2==0 else 0.0))
			body.set_pixel(x,y,Color((x+0.3)/8.0,(y+0.3)/8.0,ids[x],0))
			head.set_pixel(x,y,Color((7-x+0.4)/8.0,(7-y+0.4)/8.0,0.1 if y%3!=0 else 0.0,1.0 if y%2==0 else 0.0))
	var enabled := {&"gloves":true,&"shoes":true,&"left_eye":true,&"right_eye":true}
	var colors := {&"left_hand":Color.RED,&"right_hand":Color.BLUE,&"left_foot":Color.GREEN,&"right_foot":Color.YELLOW,&"left_eye":Color.BLACK,&"right_eye":Color.MAGENTA}
	var index := 0
	for key in Binder.LAYERS:
		var im := Image.create(8,8,false,Image.FORMAT_RGBAF)
		for y in 8:
			for x in 8:
				im.set_pixel(x,y,Color(x/8.0,y/8.0,index/10.0,1.0 if (x+y+index)%3==0 else 0.0))
		images[key]=im
		layers[key]={"texture":ImageTexture.create_from_image(im),"rect":rect}
		enabled[key]=true
		index+=1
	var viewport := SubViewport.new()
	viewport.size=Vector2i(8,8)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var plane := ColorRect.new()
	plane.size=Vector2(8,8)
	viewport.add_child(plane)
	for front in [false,true]:
		var bound := Binder.create(ImageTexture.create_from_image(main),ImageTexture.create_from_image(body),ImageTexture.create_from_image(head),front,enabled,layers,colors)
		if not bound.ok:
			push_error(bound.reason)
			quit(1)
			return
		plane.material=bound.material
		await process_frame
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		for y in 8:
			for x in 8:
				var b := body.get_pixel(x,y)
				var h := head.get_pixel(x,y)
				var parts := {&"torso":x==1,&"left_eye":x==2,&"right_eye":x==3,&"left_hand":x==4,&"right_hand":x==5,&"left_foot":x==6,&"right_foot":x==7,&"head":y%3!=0}
				body_rg=Vector2(b.r,b.g)
				head_rg=Vector2(h.r,h.g)
				var expected := Mix.compose(main.get_pixel(x,y),parts,h.a,front,enabled,colors,sample_body,sample_head)
				var target: Color=expected.color
				target.a=expected.coverage
				var got := actual.get_pixel(x,y)
				checks+=1
				# 透明像素 RGB 不可用于判断帧缓冲混合，非透明像素逐通道检查。
				if abs(got.a-target.a)>0.01 or (target.a>0.99 and (Vector3(got.r,got.g,got.b)-Vector3(target.r,target.g,target.b)).length()>0.015):
					failures+=1
					push_error("图形像素不符 front=%s x=%s y=%s actual=%s expected=%s"%[front,x,y,got,target])
	viewport.queue_free()
	await process_frame
	if failures==0: print("PASS equipment_subset_gpu: ",checks)
	quit(1 if failures else 0)
