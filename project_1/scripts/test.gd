extends Node2D

@export var particle_size : float = 40;
		
@export var number_of_particles: int = 100:
	set(value):
		particle_size = value;
		init_arrays();

@export var positions: Array;
@export var pressures: Array;
	
func _on_ready() -> void:
	init_arrays();
	
func init_arrays() -> void:
	positions.resize(number_of_particles);
	positions.fill(Vector2());
	
	pressures.resize(number_of_particles);
	pressures.fill(Vector2());
	
func _on_draw() -> void:
	if pressures.size() != 0:
		for i in number_of_particles:
			draw_circle(positions[i], particle_size, Color.SKY_BLUE, true, -1.0, true);
			draw_line(positions[i], positions[i] + pressures[i], Color.GREEN);
