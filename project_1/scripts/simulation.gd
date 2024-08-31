extends Node2D

#region Simulation Properties
## Should the position of the particles be updated
@export var simulate_physics: bool = true;
		
## How much energy should be conserved on collision. 1.0 = No energy lost => Infinite bounce
@export var collision_damping : float = 1;

## Bounding rectangle defining where particles can go; where the limits are
@export var bounds_size : Vector2 = Vector2(1600, 1100):
	get:
		return bounds_size;
	set(value):
		bounds_size = value;
		## When this value is changed calculate an actual Rectange that can be used for rendering
		bounds_rectangle = Rect2(Vector2(position.x - bounds_size.x / 2, position.y - bounds_size.y / 2), Vector2(bounds_size.x, bounds_size.y));

## The actual bounds used for rendering and calculation => Inferred from bounds_size
var bounds_rectangle: Rect2;

## Size of each individual particle
@export var particle_size : float = 6;
		
## The downwards force applied every frame to each particle
@export var gravity : float = 0;
		
## The total number of particles in the scene
@export var number_of_particles: int = 450;

## The density the program should try to achive by moving particles along a gradient
## The lower this value is the further apart the particles will drift
@export var target_density: float = 20:
	get:
		return target_density;
	set(value):
		target_density = value;
		Global.target_density = value;
		
## How fast/strong a particle should move along it's gradient every step to reach the target density
@export var pressure_multiplier: float = 20:
	get:
		return pressure_multiplier;
	set(value):
		pressure_multiplier = value;
		Global.pressure_multiplier = value;

## Defines the radius in which a particle has to be, to have any influence on the density/pressure
## LARGER RADIUS MEANS MORE COMPARISONS => WORSE PERFORMANCE CAUTION!
@export var smoothing_radius: float = 120:
	get:
		return smoothing_radius;
	set(value):
		smoothing_radius = value;
		## When we change the radius, calculate the density so the user can see a live update
		calculate_density_at_point_full_iteration(true, last_mouse_click)
		
## How far apart should each particle start the simulation
@export var particle_spacing: int = 30;
		
## If enabled particles can be pushed and pulled with he mouse
@export var apply_pressure_on_click: bool = true;

## How much Force should be applied by the mouse
@export var input_force: float = 2000;

## Defines the direction of the input force => 1 = away from mouse, -1 = towards mouse
var input_force_strength = 1;

## Defines if the velocity of a particel should be set to pressure value or if the pressure is accumulated on top of the existing velocity
## On means there is inertia
@export var accumulate_pressure_on_velocity: bool = true;

## The mass of each particle => Defines the intensity of each particle on the density and pressure
var mass = 1;
		
#endregion		

#region Debugging

## Renders lines showing the pressure and velocity of particles
@export var show_pressure_direction_debug: bool = false;

## Renders the Grid of the spatial lookup optimization
@export var show_spatial_grid: bool = false;

## Holds the number of how many particles a particle compared to calculate the density each tick
var density_comparisons_per_particle: Array;

## Holds the number of how many particles a particle compared to calculate the pressure each tick
var pressure_comparisons_per_particle: Array;

## The position of the last mouse_click
var last_mouse_click: Vector2;
#endregion

#region Particle Properties

## Holds the current position of all particles
## Vector2
var positions: Array;

## Holds the predicted position of all particles in a fixed "future"
## Prediction works by applying n many velocity steps of a particle
## Vector2
var predicted_positions: Array;

## Holds the velocities of all particles
## Vector2
var velocities: Array;

## Holds the density of the location of all particles
## Vector2
var densities: Array;

## Holds the current pressure a particle is experiencing
## Vector2
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

#endregion
	
## A pseudo random generator => Used for getting random direction in some instances
var rng = RandomNumberGenerator.new();

## Handle mouse click for debugging
func _input(event):
	if event is InputEventMouseButton and event.is_pressed():
		## Calculates the density at the mouse click position
		calculate_density_at_point_full_iteration(true, get_global_mouse_position());
		## Save the last mouse click location 
		last_mouse_click = get_global_mouse_position();
		
		## Calculate the spatial properties only if the grid is shown
		if show_spatial_grid: 
			Global.sample_cell_coords = HashHelpers.position_to_cell_coord(last_mouse_click, smoothing_radius);
			Global.sample_cell_key = get_key_from_hash(HashHelpers.hash_cell(Global.sample_cell_coords.x, Global.sample_cell_coords.y))

#region Startup

func _ready() -> void:
	#region Global_Init
	## Initialize all values with defaults
	
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
	
	density_comparisons_per_particle.resize(number_of_particles);
	density_comparisons_per_particle.fill(0);
	
	pressure_comparisons_per_particle.resize(number_of_particles);
	pressure_comparisons_per_particle.fill(0);
	
	#endregion
	spawn_particles_as_grid();

## Spawns all particles in a grid like way
func spawn_particles_as_grid() -> void:
	var particles_per_row: int = ceil(pow(number_of_particles, 1.0/2.0));
	var particles_per_col = (number_of_particles - 1) / particles_per_row + 1;
	var spacing = particle_size * 2 + particle_spacing;
	
	for i in number_of_particles:
		var x = (i % particles_per_row - particles_per_row / 2.0 + 0.5) * spacing;
		var y = (i / particles_per_row - particles_per_col / 2.0 + 0.5) * spacing;
		positions[i] = Vector2(x, y);
		
#endregion


## The main function of the simulation. Runs every tick and calculates all properties and applies them
func _process(delta: float) -> void:
	
	## Reset the densities and pressures to start accumulating again
	densities.fill(0.0);
	pressures.fill(Vector2());
	
	## Reset the debugging values
	density_comparisons_per_particle.fill(0);
	pressure_comparisons_per_particle.fill(0);
	Global.average_density_comparisons_per_particle = 0;
	Global.average_pressure_comparisons_per_particle = 0;
	
	## Calculate the predictes postion of each particle in n-many timesteps by applying that much of it's velocity
	for i in number_of_particles:
		predicted_positions[i] = positions[i] + velocities[i] * (1.0 / 60.0);
	
	## Update the spatial lookup grid cell location of every particle
	update_spatial_lookup();
	
	## Calculte the density of each particle
	for i in number_of_particles:
		accumulate_density(i, get_neighboring_particles_within_radius(predicted_positions[i]));
		
	## Calculate the pressure of each particle using it's density
	for i in number_of_particles:
		accumulate_pressure(i, get_neighboring_particles_within_radius(predicted_positions[i]));
	
	## Only update the velocity and position when the user wants to
	if simulate_physics:
		for i in number_of_particles:
			## How much of the pressure should be applied to a particle based on the density
			var pressure_acceleration = pressures[i] / densities[i];
			
			## Either add or set the velocity using the pressure_acceleration
			if accumulate_pressure_on_velocity:
				velocities[i] += pressure_acceleration * delta;	
			else:
				velocities[i] = pressure_acceleration * delta;	
				
			## Apply gravity
			velocities[i] += Vector2.DOWN * gravity * delta;
			
		## Apply the mouse force to each particle in radius
		if (Input.is_mouse_button_pressed(1) or Input.is_mouse_button_pressed(2)) and apply_pressure_on_click:
			input_force_strength = 1 if Input.is_mouse_button_pressed(1) else -1;
			var mouse_position = get_global_mouse_position();
			for i in get_neighboring_particles_within_radius(mouse_position):
				var dir = (predicted_positions[i] - mouse_position).normalized();
				## Modify the velocity by the input_force into or away from the mouse based on the input_force_strength
				velocities[i] += input_force * dir * input_force_strength * delta;
		
		## Apply friction to all particles to prevent chaotic acceleration
		for i in number_of_particles:
			velocities[i] = velocities[i] * 0.95;
		
		## Update the positions by the velocity for rendering
		update_positions(delta);
		
		## If the particle hits a wall => Handle it
		resolve_collision();
	
	## Update the debugging information
	for i in range(density_comparisons_per_particle.size()):
		Global.average_density_comparisons_per_particle += density_comparisons_per_particle[i];
		Global.average_pressure_comparisons_per_particle += pressure_comparisons_per_particle[i];
	Global.average_density_comparisons_per_particle /= number_of_particles;
	Global.average_pressure_comparisons_per_particle /= number_of_particles;
	
	## Render everything
	queue_redraw();

func get_neighboring_particles_within_radius(point: Vector2) -> Dictionary:
	var neighbor_particle_indices: Dictionary = {};
	## Takes the position-vector of the origin particle and translates it to the coordinate of a gridcell with size smoothing_radius
	## This builds a grid of smoothing-radius sized cells which can be addressed by an x/y cell coord 
	var cell_of_sample = HashHelpers.position_to_cell_coord(point, smoothing_radius);
	
	## Square distance calculations on vectors are more efficient than normal distance
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
			var sqr_distance = (predicted_positions[particle_index] - point).length_squared();
			
			## If the particles are close enough => consider them for density and pressure
			if sqr_distance <= sqr_radius:
				neighbor_particle_indices[particle_index] = particle_index;
	return neighbor_particle_indices;
	
#region spatial_lookup

## Update the arrays holding the spatial lookup information
## Associates all particles with their respective grid cell key and saves the starting index of each cell key 
func update_spatial_lookup() -> void:
	## Iterate through all particles and associate their index with the cell key they're in
	for i in number_of_particles:
		var cell = HashHelpers.position_to_cell_coord(predicted_positions[i], smoothing_radius);
		var cell_key = get_key_from_hash(HashHelpers.hash_cell(cell.x, cell.y))
		spatial_lookup[i] = Vector2(i, cell_key);
		start_indices[i] = 9223372036854775807;
	
	## Sort the array to group all cell keys
	spatial_lookup.sort_custom(sort_by_cell);
		
	## Record the starting index of each cell key group
	for i in number_of_particles:
		var key = spatial_lookup[i].y;
		var keyPrev = 9223372036854775807 if i == 0 else spatial_lookup[i - 1].y
		if key != keyPrev:
			start_indices[key] = i;


#endregion

#region densities

func accumulate_density(origin_particle_index: int, comparer_particle_indices: Dictionary) -> void:
	for i in comparer_particle_indices:
		density_comparisons_per_particle[origin_particle_index] += 1;
		var dist = (predicted_positions[i] - predicted_positions[origin_particle_index]).length();
		var influence = Global.smoothing_kernel(smoothing_radius, dist);
		densities[origin_particle_index] += mass * influence;

#region Old even slower code

#func update_densities_full_iteration() -> void:
	#for i in number_of_particles:
		#densities[i] = calculate_density_full_iteration(i);
#
### Calculates the densitiy of particles at a specific point inside of a set radius
#func calculate_density_full_iteration(particle_index: int) -> float:
	#var density = 0.0;
	#
	### Loop over all particles and calculate their distance to the sample point
	### With that distance we can calculate the influence
	### The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	#for i in number_of_particles:
			#var dist = (positions[i] - positions[particle_index]).length();
			#var influence = Global.smoothing_kernel(smoothing_radius, dist);
			#density += mass * influence;
	#return density;
	
#endregion

## Just used for debugging => Iterates through all particles => slow
func calculate_density_at_point_full_iteration(debug: bool, sample_position: Vector2) -> float:
	if positions.size() == 0: return 0;
	
	var density = 0.0;
	
	## Loop over all particles and calculate their distance to the sample point
	## With that distance we can calculate the influence
	## The resulting density is the mass of each individual particle * it's influence on the density => accumulated
	for i in number_of_particles:
			var dist = (positions[i] - sample_position).length();
			var influence = Global.smoothing_kernel(smoothing_radius, dist);
			density += mass * influence;
	
	if debug: print("Density: ", density);
	
	## Debugging property
	Global.sample_density = density * 100;
	return density;

#endregion

#region pressure
## Calculate and accumulate all pressure that is influencing the given particle
func accumulate_pressure(origin_particle_index: int, comparer_particle_indices: Dictionary) -> void:
	for i in comparer_particle_indices:
		##  For Debugging 
		pressure_comparisons_per_particle[origin_particle_index] += 1;
		
		var origin_particle_position = predicted_positions[origin_particle_index];
		var comparer_particle_position = predicted_positions[i];
		
		## Skip this particle if it is itself
		if i == origin_particle_index: continue;
		## Get the distance from the origin to the comparer
		var dist = (comparer_particle_position - origin_particle_position).length();
		## Get the direction from the origin to the comparer or a random direction if they are on-top of each other
		var dir = get_random_direction() if dist == 0 else (comparer_particle_position - origin_particle_position) / dist;
		
		## Calculate the slope of the density function at the distance to determin how much influence the comparer has on the pressure
		var slope = Global.smoothing_kernel_derivative(smoothing_radius, dist);
		var density = densities[i];
		
		## If the density is 0 skip since we don't want to divide by 0
		if is_equal_approx(density, 0):
			continue;
		## Get the shared pressure of both particles to account for Newtons second law => a particle that pushes is also pushed back
		var shared_pressure = Global.calculate_shared_pressure(density, densities[origin_particle_index])
		
		## The resulting pressure is the accumlated pressure of all surrounding particles, scaled by how close they are to the origin
		pressures[origin_particle_index] += shared_pressure * dir * slope * mass / density;
		
#region Old even slower code
	
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
#endregion

#region positions

## Applies the velocity of all particles to their position based on delta
func update_positions(delta: float) -> void:
	for i in number_of_particles:
		positions[i] += calculate_position(i, delta);
		
func calculate_position(particle_index: int, delta: float) -> Vector2:
	return velocities[particle_index] * delta;

#endregions

#region misc

## Transforms a spatial lookup grid key to a index in the array => Since this array is finite, duplicates can exist but should be reduced as much as possible 
func get_key_from_hash(input_hash: int) -> int:
	var result = input_hash % spatial_lookup.size();
	return result;

## Sorts the spatial lookup by the cell key
func sort_by_cell(a: Vector2i, b: Vector2i):
	return a.y < b.y;

func get_random_direction() -> Vector2:
	return Vector2(rng.randf(), rng.randf());
	
## Pushes particles that are beyond the boundaries inside
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

## Debugging: Draws the spatial lookup grid. One Rectange is one Cell
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

## Debugging: Returns all particles in the spatial lookup of the selected Cell
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

## Renders all particles, grids and lines
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
