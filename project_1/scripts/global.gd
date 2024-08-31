extends Node

#region global_simulation_properties
## The density the program should try to achive by moving particles along a gradient
var target_density: float;

## How fast/strong a particle should move along it's gradient every step to reach the target density
var pressure_multiplier: float;

#endregion

var sample_density: float;
var sample_cell_coords: Vector2i;
var sample_cell_key: int;
var average_density_comparisons_per_particle: float;
var average_pressure_comparisons_per_particle: float;

## Converts a given density at a point to the pressure that should be applied to the particle to move it towards the target density
func convert_density_to_pressure(density: float) -> float:
	var density_error = density - target_density / 100;
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
	return ((radius - dist) * (radius - dist) / volume) * 1000;

func smoothing_kernel_derivative(radius: float, dist: float) -> float:
	## Particle is outside of the smoothing radius => Influence of this point will be 0
	if dist >= radius: return 0;
	
	## Derivative of the smoothing function as given by Wolfram Alpha
	var scale = 12 / (PI * pow(radius, 4));
	return scale * (dist - radius) * 5000000;
	
