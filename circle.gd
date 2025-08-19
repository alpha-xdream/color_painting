extends Area2D

# 真正弹出的菜单，运行时生成
var popup := PopupMenu.new()

func _ready():
	add_child(popup)
	# 随便加几个选项
	popup.add_item("旋转 90°")
	popup.add_item("删除")
	popup.id_pressed.connect(_on_menu_selected)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	#print("Mouse right start", event, event.pressed, event.button_index)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# 让菜单出现在鼠标位置
		popup.position = get_global_mouse_position()
		popup.reset_size()   # 保险起见刷新一下大小
		popup.popup()
		get_viewport().set_input_as_handled()   # 吃掉事件

func _on_menu_selected(id: int) -> void:
	match id:
		0: rotation_degrees += 90
		1: queue_free()
