extends Node

#region global_simulation_properties
## Should physics be processed for particles
var simulate_physics: bool;

## Bounding rectangle defining where particles can go; where the limits are
var bounds_rectangle: Rect2;

## How much energy should be conserved on collision. 1.0 = No energy lost => Infinite bounce
var collision_damping : float;

## The total number of particles in the scene
var number_of_particles: int;

## The downwards force applied every frame to each particle
var gravity: float;

## The density the program should try to achive by moving particles along a gradient
var target_density: float;

## How fast/strong a particle should move along it's gradient every step to reach the target density
var pressure_multiplier: float;

#endregion
var positions: Array;
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

var colors: Dictionary;

var sample_density: float;
var sample_cell_coords: Vector2i;
var sample_cell_key: int;

## Converts a given density at a point to the pressure that should be applied to the particle to move it towards the target density
func convert_density_to_pressure(density: float) -> float:
	var density_error = density - target_density;
	var pressure = density_error * pressure_multiplier;
	return pressure;
	
func calculate_shared_pressure(densityA: float, densityB: float) -> float:
	var pressureA = convert_density_to_pressure(densityA);
	var pressureB = convert_density_to_pressure(densityB);
	return (pressureA + pressureB) / 2;
	
func smoothing_kernel(radius: float, dist: float) -> float:
	if dist >= radius: return 0;
	
	## Volume calculation formular for the volume of the smoothing function as given by Wolfram Alpha
	var volume = PI * pow(radius, 4) / 6;
	return (radius - dist) * (radius - dist) / volume;

func smoothing_kernel_derivative(radius: float, dist: float) -> float:
	## Particle is outside of the smoothing radius => Influence of this point will be 0
	if dist >= radius: return 0;
	
	## Derivative of the smoothing function as given by Wolfram Alpha
	var scale = 12 / (PI * pow(radius, 4));
	return scale * (dist - radius);
	
