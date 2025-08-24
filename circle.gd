extends Area2D
class_name Circle
@onready var circle: Sprite2D = $Circle

# 允许拖拽
#var _dragging := false
#var _click_offset := Vector2.ZERO
#
#func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	#print("circle _gui_input", name)
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#if event.pressed:
				#_dragging = true
				#_click_offset = get_global_mouse_position() - global_position
				##set_process_input(true)  # 继续监听移动
			#else:
				#_dragging = false
				##set_process_input(false)
		#else:
			#_dragging = false
#
	##get_viewport().set_input_as_handled()
	#if _dragging:
		#global_position = get_global_mouse_position() + _click_offset
#
		
func set_color(color:Color):
	circle.modulate = color
