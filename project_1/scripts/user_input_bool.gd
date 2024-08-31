extends CheckButton

func _on_ready() -> void:
	var game_node = get_node("/root/Game");

	match name:
		"Show Pressure":
			button_pressed = game_node.show_pressure_direction_debug ;
		"Show Grid":
			button_pressed = game_node.show_spatial_grid ;
		"Accumulate Velocity":
			button_pressed = game_node.accumulate_pressure_on_velocity ;
		"Apply Input Force":
			button_pressed = game_node.apply_pressure_on_click ;

func _on_toggled(toggled_on: bool) -> void:
	var game_node = get_node("/root/Game");
	match name:
		"Show Pressure":
			game_node.show_pressure_direction_debug = toggled_on;
		"Show Grid":
			game_node.show_spatial_grid = toggled_on;
		"Accumulate Velocity":
			game_node.accumulate_pressure_on_velocity = toggled_on;
		"Apply Input Force":
			game_node.apply_pressure_on_click = toggled_on;
