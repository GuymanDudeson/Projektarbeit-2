extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	text = "Avg. Density comparisons per particle: %.2f" % Global.average_density_comparisons_per_particle;
