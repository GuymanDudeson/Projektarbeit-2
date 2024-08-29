extends Node

#region global_simulation_properties
## Should physics be processed for particles
var simulate_physics: bool;

## Bounding rectangle defining where particles can go; where the limits are
var bounds_rectangle: Rect2;

## How much energy should be conserved on collision. 1.0 = No energy lost => Infinite bounce
var collision_damping : float;

## The total number of particles in the scene
var number_of_particles: float;

## The scale of the individual particles
var particle_scale: float;

## The downwards force applied every frame to each particle
var gravity: float;

## The density the program should try to achive by moving particles along a gradient
var target_density: float;

## How fast/strong a particle should move along it's gradient every step to reach the target density
var pressure_multiplier: float;

#endregion

var densities: Dictionary;
var pressures: Dictionary;

var colors: Dictionary;

var sample_density: float;

## Converts a given density at a point to the pressure that should be applied to the particle to move it towards the target density
func convert_density_to_pressure(density: float) -> float:
	var density_error = density - target_density;
	var pressure = density_error * pressure_multiplier;
	return pressure;

func smoothing_kernel(radius: float, dist: float) -> float:
	## Volume calculation formular for the volume of the smoothing function as given by Wolfram Alpha
	var volume = PI * pow(radius, 8) / 4;
	var value = max(0, radius * radius - dist * dist);
	return value * value * value / volume;

func smoothing_kernel_derivative(radius: float, dist: float) -> float:
	## Particle is outside of the smoothing radius => Influence of this point will be 0
	if dist >= radius: return 0;
	var f = radius * radius - dist * dist;
	## Derivative of the smoothing function as given by Wolfram Alpha
	var scale = -24 / (PI * pow(radius, 8));
	return scale * dist * f * f;
	
