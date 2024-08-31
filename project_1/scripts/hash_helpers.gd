extends Node

var cell_offsets = [
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(-1, 0),
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]

func position_to_cell_coord(point: Vector2i, radius: float) -> Vector2:
	var cell_x: int = floor(point.x / radius);
	var cell_y: int = floor(point.y / radius);
	return Vector2(cell_x, cell_y);

## Calculate a Hash that is unlikely to repeat itself
## Basis is multiplication by a prime number
## Fun-fact: First prime numbers chosen by random where [(15823, 139999), (9737333, 9599977)] 
## => These resulted in duplicate entries for example for cell_key 215 for the inputs (3, 2) and (-2, 1) since the modulo(220) of 19522135 and 9879975 are the same
## Changing one of the primes from 15823 -> 16001 resolved this. But the calculation is finnicky once you play around with the grid-size, number_of_particles or other properties
func hash_cell(cell_x: int, cell_y: int) -> int:
	var a: int = cell_x * 16001 if sign(cell_x) != -1 else cell_x * 139999;
	var b: int = cell_y * 9737333 if sign(cell_y) != -1 else cell_y * 9599977;
	return abs(a + b);
