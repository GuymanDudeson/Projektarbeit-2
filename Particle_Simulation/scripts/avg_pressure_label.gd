extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = "Avg. Pressure comparisons per particle: %.2f" % Global.average_pressure_comparisons_per_particle;
