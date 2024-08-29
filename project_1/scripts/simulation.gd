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

@export var bounds_size : Vector2 = Vector2(1000, 600):
	get:
		return bounds_size;
	set(value):
		bounds_size = value;
		Global.bounds_rectangle = Rect2(Vector2(position.x - bounds_size.x / 2, position.y - bounds_size.y / 2), Vector2(bounds_size.x, bounds_size.y));
		
@export var particle_size : float = 5:
	get:
		return particle_size;
	set(value):
		particle_size = value;
		
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
		
@export var target_density: float = 1:
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
		
@export var show_pressure_direction_debug: bool = false:
	get:
		return show_pressure_direction_debug;
	set(value):
		show_pressure_direction_debug = value;
		Global.show_pressure_direction_debug = value;
		
#endregion		
		
@export var smoothing_radius: float = 50:
	get:
		return smoothing_radius;
	set(value):
		smoothing_radius = value;
		calculate_density_at_point(true, smoothing_radius_position)
		
@export var particle_spacing: int = 10;

var smoothing_radius_position: Vector2;
var mass = 1;

var rng = RandomNumberGenerator.new();

#region Debugging	
func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		calculate_density_at_point(true, get_global_mouse_position());
		smoothing_radius_position = get_global_mouse_position();
#endregion

#region Startup

func _ready() -> void:
	#region Global_Init
	
	bounds_size = bounds_size;
	Global.simulate_physics = simulate_physics;
	Global.collision_damping = collision_damping;
	Global.gravity = gravity;
	Global.number_of_particles = number_of_particles;
	Global.target_density = target_density;
	Global.pressure_multiplier = pressure_multiplier;
	Global.show_pressure_direction_debug = show_pressure_direction_debug;
	
	Global.positions.resize(number_of_particles);
	Global.positions.fill(Vector2());
	Global.velocities.resize(number_of_particles);
	Global.velocities.fill(Vector2());
	Global.pressures.resize(number_of_particles);
	Global.pressures.fill(Vector2());
	Global.densities.resize(number_of_particles);
	Global.densities.fill(1.0);
	
	#endregion
	spawn_particles_as_grid();

func spawn_particles_as_grid() -> void:
	var particles_per_row: int = ceil(pow(Global.number_of_particles, 1.0/2.0));
	var particles_per_col = (Global.number_of_particles - 1) / particles_per_row + 1;
	var spacing = particle_size * 2 + particle_spacing;
	
	for i in Global.number_of_particles:
		var x = (i % particles_per_row - particles_per_row / 2.0 + 0.5) * spacing;
		var y = (i / particles_per_row - particles_per_col / 2.0 + 0.5) * spacing;
		Global.positions[i] = Vector2(x, y);
		
#endregion


func _process(delta: float) -> void:
	#for i in self.get_children():
		#if(i is CharacterBody2D):
			#Global.colors[i.get_instance_id()] = Vector4(rng.randf_range(0,1), rng.randf_range(0,1), rng.randf_range(0,1), 1.0);
	if Global.simulate_physics:
		update_densities();
		update_pressures();
		update_velocities(delta);
		update_positions(delta);
		resolve_collision();
	queue_redraw();

#region densities

func update_densities() -> void:
	for i in Global.number_of_particles:
		Global.densities[i] = calculate_density(false, i) * 1000;

## Calculates the densitiy of particles at a specific point inside of a set radius
func calculate_density(debug: bool, particle_index: int) -> float:
	var density = 0.0;
	
	## Loop over all children that are water_drops and calculate their distance to the sample point
	## With that distance we can calculate the influence depending on our smoothing radius + smoothing function
	## The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	for i in Global.number_of_particles:
			var dist = (Global.positions[i] - Global.positions[particle_index]).length();
			var influence = Global.smoothing_kernel(smoothing_radius, dist);
			density += mass * influence;
	return density;

func calculate_density_at_point(debug: bool, sample_position: Vector2) -> float:
	if Global.positions.size() == 0: return 0;
	
	var density = 0.0;
	
	## Loop over all children that are water_drops and calculate their distance to the sample point
	## With that distance we can calculate the influence depending on our smoothing radius + smoothing function
	## The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	for i in Global.number_of_particles:
			var dist = (Global.positions[i] - sample_position).length();
			var influence = Global.smoothing_kernel(smoothing_radius, dist);
			density += mass * influence;
			
	if debug: print("Density: ", density * 1000);
	
	Global.sample_density = density * 1000;
	return density;

#endregion

#region pressure

func update_pressures() -> void:
	for i in Global.number_of_particles:
		Global.pressures[i] = calculate_pressure_force(i);
			

## Check a point next to the origin of the sample on the x and y axis and calculate how big the difference is between the origin and the steps
## Afterwards build a vector that points towards the biggest possible change
func calculate_pressure_force(particle_index: int) -> Vector2:
	var pressure_force = Vector2.ZERO;
	var particle_position = Global.positions[particle_index];
	
	for i in Global.number_of_particles:
		if i == particle_index: continue;
		var current_particle_position = Global.positions[i];
		var dist = (current_particle_position - particle_position).length();
		var dir = get_random_direction() if dist == 0 else (current_particle_position - particle_position) / dist;
		var slope = Global.smoothing_kernel_derivative(smoothing_radius, dist) * 1000000;
		var density = Global.densities[i];
		var shared_pressure = Global.calculate_shared_pressure(density, Global.densities[particle_index])
		pressure_force += shared_pressure * dir * slope * mass / density;
		
	return pressure_force;

#endregion

#region velocities
func update_velocities(delta: float) -> void:
	for i in Global.number_of_particles:
		Global.velocities[i] += calculate_velocity(i, delta);

func calculate_velocity(particle_index: int, delta: float) -> Vector2:
	var current_velocity = Vector2.DOWN * Global.gravity * delta;
	
	var pressure = Global.pressures[particle_index];
	var density = Global.densities[particle_index];
	
	var pressure_acceleration = pressure / density;
	current_velocity += pressure_acceleration * delta;
	
	return current_velocity;

#endregion

#region positions

func update_positions(delta: float) -> void:
	for i in Global.number_of_particles:
		Global.positions[i] += calculate_position(i, delta);
		
func calculate_position(particle_index: int, delta: float) -> Vector2:
	return Global.velocities[particle_index] * delta;

#endregions

#region misc

func get_random_direction() -> Vector2:
	return Vector2(rng.randf(), rng.randf());
	
func resolve_collision() -> void: 
	for i in Global.number_of_particles:
		var bounds_adjusted = abs(Global.bounds_rectangle.position) - Vector2(1.0, 1.0) * particle_size;

		if(abs(Global.positions[i].x) > bounds_adjusted.x):
			Global.positions[i].x = bounds_adjusted.x * sign(Global.positions[i].x);
			Global.velocities[i].x *= -1.0 * Global.collision_damping;

		if(abs(Global.positions[i].y) > bounds_adjusted.y):
			Global.positions[i].y = bounds_adjusted.y * sign(Global.positions[i].y);
			Global.velocities[i].y *= -1.0 * Global.collision_damping;
	
#endregion

func _on_draw() -> void:
	draw_rect(Global.bounds_rectangle, Color.WHEAT, false, 5);
	
	for i in Global.number_of_particles:
		draw_circle(Global.positions[i], particle_size, Color.SKY_BLUE, true, -1.0, true);
		if(Global.show_pressure_direction_debug):
			draw_line(Global.positions[i], Global.positions[i] + Global.pressures[i], Color.GREEN);
			draw_line(Global.positions[i], Global.positions[i] + Global.velocities[i], Color.CORAL);
	
	if smoothing_radius_position:
		draw_circle(smoothing_radius_position, smoothing_radius, Color.CYAN, false, 1.0);
