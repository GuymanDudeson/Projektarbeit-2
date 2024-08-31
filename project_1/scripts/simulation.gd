extends Node2D

#region inputs_with_global_effect
## Should physics be processed for particles
@export var simulate_physics: bool:
	get:
		return simulate_physics;
	set(value):
		simulate_physics = value;
		
## How much energy should be conserved on collision. 1.0 = No energy lost => Infinite bounce
@export var collision_damping : float = 1:
	get:
		return collision_damping;
	set(value):
		collision_damping = value;

## Bounding rectangle defining where particles can go; where the limits are
@export var bounds_size : Vector2 = Vector2(1800, 1100):
	get:
		return bounds_size;
	set(value):
		bounds_size = value;
		bounds_rectangle = Rect2(Vector2(position.x - bounds_size.x / 2, position.y - bounds_size.y / 2), Vector2(bounds_size.x, bounds_size.y));
		
@export var particle_size : float = 6:
	get:
		return particle_size;
	set(value):
		particle_size = value;
		
## The downwards force applied every frame to each particle
@export var gravity : float = 0:
	get:
		return gravity;
	set(value):
		gravity = value;
		
## The total number of particles in the scene
@export var number_of_particles: int = 450:
	get:
		return number_of_particles;
	set(value):
		number_of_particles = value;
		
@export var target_density: float = 20:
	get:
		return target_density;
	set(value):
		target_density = value;
		Global.target_density = value;
		
@export var pressure_multiplier: float = 60000:
	get:
		return pressure_multiplier;
	set(value):
		pressure_multiplier = value;
		Global.pressure_multiplier = value;
		
@export var show_pressure_direction_debug: bool = false;
@export var show_spatial_grid: bool = false;
@export var accumulate_pressure_on_velocity: bool = true;
		
#endregion		

var positions: Array;
var predicted_positions: Array;
var velocities: Array;
var densities: Array;
var pressures: Array;

## Array of Vector2i containing information about the cell-location of a particle
## Vector is build as (actual_index_of_particle, cell_key)
var spatial_lookup: Array;

## Array of int containing information about the index inside the spatial_lookup where the entries for a cell_key start
## Example: Cell 0 contains 2 particles with index [6 , 8], Cell 1 contains 3 particles with index [2, 3, 4] 
## => Spatial_Lookup will look like: [(6, 0), (8, 0), (2, 1), (3, 1), (4, 1)]
## => Start_indeces will look like: [0, 2, inf, inf, inf, inf]
## => If we want to get all particles in cell 1 we get the entry in start_indeces at index 1 => 2
## The particles in cell 1 start in the Spatial_Lookup at index 2
var start_indices: Array;
	
@export var smoothing_radius: float = 120:
	get:
		return smoothing_radius;
	set(value):
		smoothing_radius = value;
		calculate_density_at_point_full_iteration(true, last_mouse_click)
		
var bounds_rectangle: Rect2;
		
@export var particle_spacing: int = 30;

var last_mouse_click: Vector2;
var mass = 1;

var rng = RandomNumberGenerator.new();

#region Debugging	
func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		calculate_density_at_point_full_iteration(true, get_global_mouse_position());
		last_mouse_click = get_global_mouse_position();
		if show_spatial_grid: 
			Global.sample_cell_coords = HashHelpers.position_to_cell_coord(last_mouse_click, smoothing_radius);
			Global.sample_cell_key = get_key_from_hash(HashHelpers.hash_cell(Global.sample_cell_coords.x, Global.sample_cell_coords.y))
#endregion

#region Startup

func _ready() -> void:
	#region Global_Init
	bounds_size = bounds_size;
	Global.target_density = target_density;
	Global.pressure_multiplier = pressure_multiplier;
	
	spatial_lookup.resize(number_of_particles);
	spatial_lookup.fill(Vector2i());
	
	start_indices.resize(number_of_particles);
	start_indices.fill(9223372036854775807);
	
	positions.resize(number_of_particles);
	positions.fill(Vector2());
	
	predicted_positions.resize(number_of_particles);
	predicted_positions.fill(Vector2());
	
	velocities.resize(number_of_particles);
	velocities.fill(Vector2());
	
	pressures.resize(number_of_particles);
	pressures.fill(Vector2());
	
	densities.resize(number_of_particles);
	densities.fill(1.0);
	
	#endregion
	spawn_particles_as_grid();

func spawn_particles_as_grid() -> void:
	var particles_per_row: int = ceil(pow(number_of_particles, 1.0/2.0));
	var particles_per_col = (number_of_particles - 1) / particles_per_row + 1;
	var spacing = particle_size * 2 + particle_spacing;
	
	for i in number_of_particles:
		var x = (i % particles_per_row - particles_per_row / 2.0 + 0.5) * spacing;
		var y = (i / particles_per_row - particles_per_col / 2.0 + 0.5) * spacing;
		positions[i] = Vector2(x, y);
		
#endregion


func _process(delta: float) -> void:
	
	## Reset the densities and pressures to start accumulating again
	densities.fill(0.0);
	pressures.fill(Vector2());
	
	for i in number_of_particles:
		predicted_positions[i] = positions[i] + velocities[i] * (1 / 120);
	
	update_spatial_lookup();
	
	for i in number_of_particles:
		foreach_point_within_radius(i, accumulate_density);
		
	for i in number_of_particles:
		foreach_point_within_radius(i, accumulate_pressure);
	
	if simulate_physics:
		for i in number_of_particles:
			var pressure_acceleration = pressures[i] / densities[i];
			
			if accumulate_pressure_on_velocity:
				velocities[i] += pressure_acceleration * delta;	
			else:
				velocities[i] = pressure_acceleration * delta;	
				
			velocities[i] += Vector2.DOWN * gravity * delta;
			velocities[i] = velocities[i] * 0.95;
		update_positions(delta);
		resolve_collision();
		
	queue_redraw();

func foreach_point_within_radius(origin_particle_index: int, callable: Callable) -> void:
	## Takes the position-vector of the origin particle and translates it to the coordinate of a gridcell with size "smoothing_radius"
	## This builds  a grid of "smoothing-radius" sized cells which can be addressed by an x/y cell coord 
	var cell_of_sample = HashHelpers.position_to_cell_coord(positions[origin_particle_index], smoothing_radius);
	
	var sqr_radius = smoothing_radius * smoothing_radius;
	
	## Iterate though all grid cells that are next to the origin in a 3x3 fashion
	## This guarantees that the entire "smoothing_radius" of every possible point in the origin cell is considered for the density/pressure
	for cell_offset in HashHelpers.cell_offsets:
		## Get the Key of one of the cells in the 3x3 grid around the origin
		var key = get_key_from_hash(HashHelpers.hash_cell(cell_of_sample.x + cell_offset.x, cell_of_sample.y + cell_offset.y));
		
		## Use the start_indeces to get the index in the spatial_lookup of where the mapping of all the particles of that grid lies
		var cell_start_index = start_indices[key];
		
		## Iterate through all entries in the spatial_lookup (all particles in the cell) : Will break once it reaches a different key => we left the cell
		for i in range(cell_start_index, spatial_lookup.size()):
			## Stop this iteration once the key changes => we left the current cell
			if spatial_lookup[i].y != key: break;
			
			## Get the corresponding actual index of the particle in the property arrays (like position and velocity)
			var particle_index = spatial_lookup[i].x;
			
			## Get the squared distance of the current particle in the cell and the origin particle to check if it is inside the "smoothing_radius"
			var sqr_distance = (positions[particle_index] - positions[origin_particle_index]).length_squared();
			
			## If the particles are close enough => consider them for density and pressure
			if sqr_distance <= sqr_radius:
				callable.call(origin_particle_index, particle_index);
	

#region spatial_lookup

func update_spatial_lookup() -> void:
	for i in number_of_particles:
		var cell = HashHelpers.position_to_cell_coord(positions[i], smoothing_radius);
		var cell_key = get_key_from_hash(HashHelpers.hash_cell(cell.x, cell.y))
		spatial_lookup[i] = Vector2(i, cell_key);
		start_indices[i] = 9223372036854775807;
		
	spatial_lookup.sort_custom(sort_by_cell);
		
	for i in number_of_particles:
		var key = spatial_lookup[i].y;
		var keyPrev = 9223372036854775807 if i == 0 else spatial_lookup[i - 1].y
		if key != keyPrev:
			start_indices[key] = i;


#endregion

#region densities

func accumulate_density(origin_particle_index: int, comparer_particle_index: int) -> void:
	var dist = (positions[comparer_particle_index] - positions[origin_particle_index]).length();
	var influence = Global.smoothing_kernel(smoothing_radius, dist);
	densities[origin_particle_index] += mass * influence;

#func update_densities_full_iteration() -> void:
	#for i in number_of_particles:
		#densities[i] = calculate_density_full_iteration(i);
#
### Calculates the densitiy of particles at a specific point inside of a set radius
#func calculate_density_full_iteration(particle_index: int) -> float:
	#var density = 0.0;
	#
	### Loop over all children that are water_drops and calculate their distance to the sample point
	### With that distance we can calculate the influence depending on our smoothing radius + smoothing function
	### The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	#for i in number_of_particles:
			#var dist = (positions[i] - positions[particle_index]).length();
			#var influence = Global.smoothing_kernel(smoothing_radius, dist);
			#density += mass * influence;
	#return density;

func calculate_density_at_point_full_iteration(debug: bool, sample_position: Vector2) -> float:
	if positions.size() == 0: return 0;
	
	var density = 0.0;
	
	## Loop over all children that are water_drops and calculate their distance to the sample point
	## With that distance we can calculate the influence depending on our smoothing radius + smoothing function
	## The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	for i in number_of_particles:
			var dist = (positions[i] - sample_position).length();
			var influence = Global.smoothing_kernel(smoothing_radius, dist);
			density += mass * influence;
			
	if debug: print("Density: ", density);
	
	Global.sample_density = density;
	return density;

#endregion

#region pressure

func accumulate_pressure(origin_particle_index: int, comparer_particle_index: int) -> void:
	var origin_particle_position = positions[origin_particle_index];
	if comparer_particle_index == origin_particle_index: return;
	
	var comparer_particle_position = positions[comparer_particle_index];
	var dist = (comparer_particle_position - origin_particle_position).length();
	var dir = get_random_direction() if dist == 0 else (comparer_particle_position - origin_particle_position) / dist;
	var slope = Global.smoothing_kernel_derivative(smoothing_radius, dist);
	var density = densities[comparer_particle_index];
	if is_equal_approx(density, 0):
		return;
	var shared_pressure = Global.calculate_shared_pressure(density, densities[origin_particle_index])
	pressures[origin_particle_index] += shared_pressure * -dir * slope * mass / density;
	
	
#func update_pressures() -> void:
	#for i in number_of_particles:
		#pressures[i] = calculate_pressure_force(i);
			#
#
### Check a point next to the origin of the sample on the x and y axis and calculate how big the difference is between the origin and the steps
### Afterwards build a vector that points towards the biggest possible change
#func calculate_pressure_force(particle_index: int) -> Vector2:
	#var pressure_force = Vector2.ZERO;
	#var particle_position = positions[particle_index];
	#
	#for i in number_of_particles:
		#if i == particle_index: continue;
		#var current_particle_position = positions[i];
		#var dist = (current_particle_position - particle_position).length();
		#var dir = get_random_direction() if dist == 0 else (current_particle_position - particle_position) / dist;
		#var slope = Global.smoothing_kernel_derivative(smoothing_radius, dist) * 1000000;
		#var density = densities[i];
		#var shared_pressure = Global.calculate_shared_pressure(density, densities[particle_index])
		#pressure_force += shared_pressure * dir * slope * mass / density;
		#
	#return pressure_force;

#endregion

#region positions

func update_positions(delta: float) -> void:
	for i in number_of_particles:
		positions[i] += calculate_position(i, delta);
		
func calculate_position(particle_index: int, delta: float) -> Vector2:
	return velocities[particle_index] * delta;

#endregions

#region misc
func get_key_from_hash(input_hash: int) -> int:
	var result = input_hash % spatial_lookup.size();
	return result;

func sort_by_cell(a: Vector2i, b: Vector2i):
	return a.y < b.y;

func get_random_direction() -> Vector2:
	return Vector2(rng.randf(), rng.randf());
	
func resolve_collision() -> void: 
	for i in number_of_particles:
		var bounds_adjusted = abs(bounds_rectangle.position) - Vector2(1.0, 1.0) * particle_size;

		if(abs(positions[i].x) > bounds_adjusted.x):
			positions[i].x = bounds_adjusted.x * sign(positions[i].x);
			velocities[i].x *= -1.0 * collision_damping;

		if(abs(positions[i].y) > bounds_adjusted.y):
			positions[i].y = bounds_adjusted.y * sign(positions[i].y);
			velocities[i].y *= -1.0 * collision_damping;
	
#endregion

func draw_grid() -> void:
	var x_division = ceil(bounds_rectangle.size.x / smoothing_radius) * 2;
	var y_division = ceil(bounds_rectangle.size.y / smoothing_radius) * 2;
	
	for x in range(x_division):
		for y in range(y_division):
			
			# Calculate the top-left corner of the square
			var grid_cell_position = Vector2((-smoothing_radius * ceil(x_division / 2)) + x * smoothing_radius, (-smoothing_radius * ceil(y_division / 2)) + y * smoothing_radius);
			
			var square_clicked = last_mouse_click != Vector2() and last_mouse_click.x >= grid_cell_position.x and last_mouse_click.x <= grid_cell_position.x + smoothing_radius and last_mouse_click.y >= grid_cell_position.y and last_mouse_click.y <= grid_cell_position.y + smoothing_radius
			
			# Draw the square
			draw_rect(Rect2(grid_cell_position, Vector2(smoothing_radius, smoothing_radius)), Color(1, 1, 1, 0.2), square_clicked)

func get_sample_highlight_particles() -> Array:
	if !show_spatial_grid:
		return [];
	if Global.sample_cell_key > number_of_particles:
		return [];
	var highlight_particle_indices = [];
	var highlight_particles_lookup_key = Global.sample_cell_key;

	var start_index = start_indices[highlight_particles_lookup_key];
	for i in range(start_index, spatial_lookup.size()):
		var entry = spatial_lookup[i];
		if entry.y != highlight_particles_lookup_key: break;
		highlight_particle_indices.append(int(entry.x));
	return highlight_particle_indices;

func _on_draw() -> void:
	draw_rect(bounds_rectangle, Color.WHEAT, false, 5);

	if show_spatial_grid:
		draw_grid()
	if last_mouse_click:
		draw_circle(last_mouse_click, smoothing_radius, Color.CYAN, false, -1.0, false);

	var highligh_particle_indices = get_sample_highlight_particles();

	for i in number_of_particles:
		draw_circle(positions[i], particle_size, Color.SKY_BLUE if !highligh_particle_indices.has(i) else Color.CRIMSON, true, -1.0, true);
		if(show_pressure_direction_debug):
			draw_line(positions[i], positions[i] + pressures[i], Color.GREEN);
			draw_line(positions[i], positions[i] + velocities[i], Color.CORAL);
	
