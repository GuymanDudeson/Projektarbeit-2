extends Label

var format_string = "Density: {density}"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = format_string.format({"density": Global.sample_density});
