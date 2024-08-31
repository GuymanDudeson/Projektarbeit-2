extends Node

## This is a global static file that is used to hold values and methods that are shared by multiple nodes

#region global_simulation_properties
## The density the program should try to achive by moving particles along a gradient
## The lower this value is the further apart the particles will drift
var target_density: float;

## How fast/strong a particle should move along it's gradient every step to reach the target density
var pressure_multiplier: float;

#endregion

## A Debugging Property: Density at last mouse click
var sample_density: float;

## A Debugging Property: Coordinates of the spatial lookup cell of the last mouse click
var sample_cell_coords: Vector2i;

## A Debugging Property: The actual hashed key of the selected grid cell
var sample_cell_key: int;

## A Debugging Property: The average amount of particles that every particle uses to calculate it's density value
var average_density_comparisons_per_particle: float;

## A Debugging Property: The average amount of particles that every particle checks to calculate the applied pressure
var average_pressure_comparisons_per_particle: float;

## Converts a given density at a point to the pressure that should be applied to the particle to move it towards the target density
func convert_density_to_pressure(density: float) -> float:
	## How far are we away from our desired density (division by 100 is only for easier input from outside => instead of 0.05 you can input 5)
	var density_error = density - target_density / 100;
	## The resulting pressure is the distance to the target pressure scaled by an arbitrary multiplier set by the user
	var pressure = density_error * pressure_multiplier;
	return pressure;
	
## Calculates the average of two pressures. The Input is the density of two particles that influence each other
## This shared pressure is used to implement Newtons second law => When a particle pushes another, it needs to slow down by the equivalent amount
func calculate_shared_pressure(densityA: float, densityB: float) -> float:
	var pressureA = convert_density_to_pressure(densityA);
	var pressureB = convert_density_to_pressure(densityB);
	return (pressureA + pressureB) / 2;
	
## Uses a function to calculate how high a property should be based on it's distance in relation to the maximum radius
## This value is normalized by the functions volume, to make it independent of the radius when considering more values
## E.g. if the radius contains four particles with the same spacing the density should be 5, if a bigger radius contains 100 particles BUT with the same spacing the density should still be 5 
func smoothing_kernel(radius: float, dist: float) -> float:
	## Discard all values outside our search radius
	if dist >= radius: return 0;
	
	## Volume calculation formular for the volume of the smoothing function as given by Wolfram Alpha
	var volume = PI * pow(radius, 4) / 6;
	## The resulting density scaled by 1000 to make it easier to work with (would otherwise be 0.0002453564)
	return ((radius - dist) * (radius - dist) / volume) * 1000;

## Calculates the derivative of the smoothing function to get the slope at a give distance
## The Function controls how much a value matters at a certain distance by using the slope
## For example => The function should be very steep for low distances, so that particles that are really close to each other push harder than further ones
func smoothing_kernel_derivative(radius: float, dist: float) -> float:
	## Particle is outside of the smoothing radius => Influence of this point will be 0
	if dist >= radius: return 0;
	
	## Derivative of the smoothing function as given by Wolfram Alpha
	var scale = 12 / (PI * pow(radius, 4));
	## The resulting slope scaled by 5000000 to make it easier to work with (would otherwise be 0.000000012334)
	return scale * (dist - radius) * 5000000;
	
