extends Label


var format_string = "CellKey: ({cellkey_x}, {cellkey_y})"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = format_string.format({"cellkey_x": Global.sample_cell_coords.x, "cellkey_y": Global.sample_cell_coords.y});
