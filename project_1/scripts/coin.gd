extends Area2D

func _on_body_entered(body: Node2D) -> void:
	print("Wow this is coin")
	queue_free()
