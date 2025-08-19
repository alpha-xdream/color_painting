@tool
extends ColorRect
@export var LinkA : Node2D
@export var LinkB : Node2D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if LinkA == null || LinkB == null:
		return
	var v = LinkA.global_position - LinkB.global_position
	size = Vector2(v.length(), size.y)
	global_position = LinkA.global_position
	rotation = v.angle() + PI
