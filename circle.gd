extends Area2D
class_name Circle
@onready var circle: Sprite2D = $Circle
@onready var label: Label = $Label

func set_id(id:int):
	label.text = str(id)

func set_color(color:Color):
	circle.modulate = color
