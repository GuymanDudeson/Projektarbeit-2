extends Node2D

@export var simulate_physics: bool:
	get:
		return simulate_physics;
	set(value):
		simulate_physics = value;
		Global.simulate_physics = value;
		
@export var collision_damping : float = 1:
	get:
		return collision_damping;
	set(value):
		collision_damping = value;
		Global.collision_damping = value;

@export var bounds_size : Vector2 = Vector2(600, 400):
	get:
		return bounds_size;
	set(value):
		bounds_size = value;
		Global.bounds_rectangle = Rect2(Vector2(position.x - bounds_size.x / 2, position.y - bounds_size.y / 2), Vector2(bounds_size.x, bounds_size.y));
		
@export var particle_scale : float = 20:
	get:
		return particle_scale;
	set(value):
		particle_scale = value;
		Global.particle_scale = value;
		for i in self.get_children():
			if(i is CharacterBody2D):
				i.scale = Vector2(Global.particle_scale, Global.particle_scale);
		
@export var gravity : float = 980:
	get:
		return gravity;
	set(value):
		gravity = value;
		Global.gravity = value;
		
@export var number_of_particles: int = 100:
	get:
		return number_of_particles;
	set(value):
		number_of_particles = value;
		Global.number_of_particles = value;
		spawn_particles_as_grid();
		
@export var starting_density: int = 10;
@export var smoothing_radius: float = 70;
var smoothing_radius_position: Vector2;

var scene_to_instance = preload("res://scenes/water_drop.tscn")
var rng = RandomNumberGenerator.new();

func _ready() -> void:
	#region Global_Init
	
	Global.simulate_physics = simulate_physics;
	Global.collision_damping = collision_damping;
	bounds_size = bounds_size;
	Global.particle_scale = particle_scale;
	Global.gravity = gravity;
	Global.number_of_particles = number_of_particles;
	
	#endregion
	spawn_particles_as_grid();
	
			
func spawn_particles_as_grid() -> void:
	clear_all_particles();
	
	var squareSide = ceil(pow(Global.number_of_particles, 1.0/2.0));
	var singleParticleSpace = (Global.particle_scale + starting_density);
	var squareOrigin = floor((squareSide / 2)) * -singleParticleSpace;
	var drawn = 0;
	for i in squareSide:
		for j in squareSide:
			if(drawn >= Global.number_of_particles): continue;
			var x = squareOrigin + j * singleParticleSpace;
			var y = squareOrigin + i * singleParticleSpace;
			add_child(Water_Drop.new_water_drop(Vector2(x, y)));
			drawn += 1;

func clear_all_particles() -> void:
	for i in self.get_children():
		if(i is CharacterBody2D):
			remove_child(i);
			i.queue_free();

func _process(_delta: float) -> void:
	for i in self.get_children():
		if(i is CharacterBody2D):
			Global.densities[i.get_instance_id()] = Vector4(rng.randf_range(0,1), rng.randf_range(0,1), rng.randf_range(0,1), 1.0);
	queue_redraw();
		
func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		calculate_density(get_global_mouse_position());
		smoothing_radius_position = get_global_mouse_position();
		

## Calculates the densitiy of particles at a specific point
func calculate_density(samplePoint: Vector2) -> float:
	var density = 0.0;
	var mass = 1;
	
	## Loop over all children that are water_drops and calculate their distance to the sample point
	## With that distance we can calculate the influence depending on our smoothing radius + smoothing function
	## The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	for i in self.get_children():
		if(i is CharacterBody2D):
			var currentPosition = i.position;
			var dist = (currentPosition - samplePoint).length();
			var influence = Global.smoothing_kernel(smoothing_radius, dist);
			density += mass * influence;
	print("Density: ", density);
	return density;

func _on_draw() -> void:
	draw_rect(Global.bounds_rectangle, Color.WHEAT, false, 5);
	if smoothing_radius_position:
		draw_circle(smoothing_radius_position, smoothing_radius, Color.CYAN, false, 1.0);
