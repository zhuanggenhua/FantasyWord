extends SceneTree
## 验证原训练假人的空反馈槽及时序，不以测试计数冒充视觉反馈完成。
const Cue = preload("res://gameplay/clickmovetest/training_hit_feedback_cue.gd")
var checks := 0
var errors := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors += 1
		printerr("FAIL: ", label)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var cue := Cue.new()
	var target := Node2D.new()
	root.add_child(target)
	target.position = Vector2(2,3)
	check(not cue.request(null,1) and not cue.request(target,0),"缺少目标或效果身份拒绝")
	check(cue.request(target,1),"应用阶段登记目标 Cue")
	check(cue.activation_count==0 and not cue.is_playing(1),"应用阶段不抢跑 Display")
	target.position = Vector2(4,5)
	check(cue.flush_display()==1,"不依赖效果存活，在 Display 激活")
	check(cue.last_activation.position==Vector2(4,5),"使用 Display 时刻的目标根位置")
	check(cue.last_activation.cue_id==20001 and cue.last_activation.kind==6 and cue.last_activation.target_side==0,"精确事件和目标侧")
	check(not cue.last_activation.feedback_slot_configured and cue.missing_slot_count==1,"原空槽明确保留，不伪造反馈")
	check(cue.is_playing(1) and cue.flush_display()==0,"没有源 Stop/Kill，不反复激活")
	cue.request(target,1)
	cue.request(target,1)
	check(cue.flush_display()==1,"同一 Cue 的 Play(true) 在 Display 前不重复排队")
	cue.request(target,2)
	cue.request(target,3)
	check(cue.flush_display()==2,"不同效果拥有各自独立 Cue")
	cue.request(target,4)
	target.free()
	check(cue.flush_display()==0 and cue.activation_count==4,"目标已释放不读取悬空角色")
	cue.dispose()
	check(not cue.is_playing(1) and cue.flush_display()==0,"场景退出清理 owner")
	if errors==0: print("PASS training_hit_feedback_cue: ",checks," checks, ",errors," failures")
	quit(1 if errors else 0)
