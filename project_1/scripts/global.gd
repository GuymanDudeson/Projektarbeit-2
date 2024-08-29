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

## Whether the particles should show a small green line indicating where pressure is pushing them
var show_pressure_direction_debug: bool;

#endregion
var positions: Array;
var velocities: Array;
var densities: Array;
var pressures: Array;

var colors: Dictionary;

var sample_density: float;

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
	
