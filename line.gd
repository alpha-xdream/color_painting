@tool
extends ColorRect
@export var LinkA : Node2D
@export var LinkB : Node2D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	size = Vector2(abs(LinkA.global_position.x - LinkB.global_position.x), size.y)
	global_position = Vector2((LinkA.global_position.x + LinkB.global_position.x) * 0.5, (LinkA.global_position.y + LinkB.global_position.y) * 0.5) - size/2
