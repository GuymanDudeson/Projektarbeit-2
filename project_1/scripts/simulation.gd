extends Node2D

#region inputs_with_global_effect
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
		
@export var target_density: float = 10:
	get:
		return target_density;
	set(value):
		target_density = value;
		Global.target_density = value;
		
@export var pressure_multiplier: float = 1:
	get:
		return pressure_multiplier;
	set(value):
		pressure_multiplier = value;
		Global.pressure_multiplier = value;
		
#endregion		
		
@export var smoothing_radius: float = 50:
	get:
		return smoothing_radius;
	set(value):
		smoothing_radius = value;
		calculate_density(true, smoothing_radius_position)
		
@export var starting_density: int = 10;

var smoothing_radius_position: Vector2;
var mass = 1;

var scene_to_instance = preload("res://scenes/water_drop.tscn")
var rng = RandomNumberGenerator.new();

#region Debugging	
func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		calculate_density(true, get_global_mouse_position());
		smoothing_radius_position = get_global_mouse_position();
#endregion

#region Startup

func _ready() -> void:
	#region Global_Init
	
	bounds_size = bounds_size;
	Global.simulate_physics = simulate_physics;
	Global.collision_damping = collision_damping;
	Global.particle_scale = particle_scale;
	Global.gravity = gravity;
	Global.number_of_particles = number_of_particles;
	Global.target_density = target_density;
	Global.pressure_multiplier = pressure_multiplier;
	
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
			var starting_position = Vector2(x, y);
			var new_drop = Water_Drop.new_water_drop(starting_position);
			add_child(new_drop);
			drawn += 1;

func clear_all_particles() -> void:
	
	for i in self.get_children():
		if(i is CharacterBody2D):
			remove_child(i);
			i.queue_free();

#endregion


func _process(delta: float) -> void:
	#for i in self.get_children():
		#if(i is CharacterBody2D):
			#Global.colors[i.get_instance_id()] = Vector4(rng.randf_range(0,1), rng.randf_range(0,1), rng.randf_range(0,1), 1.0);
	update_densities();
	update_pressures();
	queue_redraw();

#region densities

func update_densities() -> void:
	for particle in self.get_children():
		if(particle is CharacterBody2D):
			Global.densities[particle.get_instance_id()] = calculate_density(false, particle.position) * 1000;

## Calculates the densitiy of particles at a specific point inside of a set radius
func calculate_density(debug: bool, samplePoint: Vector2) -> float:
	var density = 0.0;
	
	## Loop over all children that are water_drops and calculate their distance to the sample point
	## With that distance we can calculate the influence depending on our smoothing radius + smoothing function
	## The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	for i in self.get_children():
		if(i is CharacterBody2D):
			var currentPosition = i.position;
			var dist = (currentPosition - samplePoint).length();
			var influence = Global.smoothing_kernel(smoothing_radius, dist);
			density += mass * influence;
			
	if debug: print("Density: ", density);
	
	Global.sample_density = density * 100;
	return density;

#endregion

#region pressure

func update_pressures() -> void:
	for particle in self.get_children():
		if(particle is CharacterBody2D):
			Global.pressures[particle.get_instance_id()] = calculate_pressure_force(particle);

## Check a point next to the origin of the sample on the x and y axis and calculate how big the difference is between the origin and the steps
## Afterwards build a vector that points towards the biggest possible change
func calculate_pressure_force(particle: CharacterBody2D) -> Vector2:
	var pressure_force = Vector2.ZERO;
	var particle_position = particle.position;
	
	for i in self.get_children():
		if(i is CharacterBody2D):
			if particle.get_instance_id() == i.get_instance_id(): continue;
			
			var current_particle_position = i.position;
			var dist = (current_particle_position - particle_position).length();
			var dir = get_random_direction() if dist == 0 else (current_particle_position - particle_position) / dist;
			var slope = Global.smoothing_kernel_derivative(smoothing_radius, dist) * 1000000;
			var density = Global.densities[i.get_instance_id()];
			var density_pressure = -Global.convert_density_to_pressure(density);
			pressure_force += -density_pressure * dir * slope * mass / density;
	return pressure_force;

#endregion

func get_random_direction() -> Vector2:
	return Vector2(rng.randf(), rng.randf());

func _on_draw() -> void:
	draw_rect(Global.bounds_rectangle, Color.WHEAT, false, 5);
	if smoothing_radius_position:
		draw_circle(smoothing_radius_position, smoothing_radius, Color.CYAN, false, 1.0);
