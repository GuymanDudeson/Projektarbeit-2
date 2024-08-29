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

#endregion

var densities: Dictionary;

var sample_density: float;


func smoothing_kernel(radius: float, dist: float) -> float:
	## Volume calculation formular for the volume of the smoothing function as given by Wolfram Alpha
	var volume = PI * pow(radius, 8) / 4;
	var value = max(0, radius * radius - dist * dist);
	return value * value * value / volume;
	
