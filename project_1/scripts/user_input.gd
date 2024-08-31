extends SpinBox

func _on_ready() -> void:
	var game_node = get_node("/root/Game");
	
	match name:
		"Gravity":
			value = game_node.gravity;
		"Target Density":
			value = game_node.target_density;
		"Pressure Multiplier":
			value = game_node.pressure_multiplier;
		"Input Force":
			value = game_node.input_force;
		"Smoothing Radius":
			value = game_node.smoothing_radius;


func _on_value_changed(value: float) -> void:
	var game_node = get_node("/root/Game");
	match name:
		"Gravity":
			game_node.gravity = value;
		"Target Density":
			game_node.target_density = value;
		"Pressure Multiplier":
			game_node.pressure_multiplier = value;
		"Input Force":
			game_node.input_force = value;
		"Smoothing Radius":
			game_node.smoothing_radius = value;
