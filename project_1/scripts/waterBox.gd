extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(transform)
	material.set_shader_parameter("parent_transform", transform);
