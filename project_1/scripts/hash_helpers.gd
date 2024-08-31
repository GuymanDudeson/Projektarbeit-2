extends Node

## This is a static helper that is used for the spatial-location optimization

## Holds offsets that specify all grid cell keys in a 3x3 grid around the origin
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

## Translates a position in space to a cell coordinate based on the smoothing radius
func position_to_cell_coord(point: Vector2i, radius: float) -> Vector2:
	## We floor the value to prevent something like -60/100 = 0 and 60/100 = 0 => Negative and positive cells get unique values
	var cell_x: int = floor(point.x / radius);
	var cell_y: int = floor(point.y / radius);
	return Vector2(cell_x, cell_y);

## Calculate a Hash that is unlikely to repeat itself
## Basis is multiplication by a prime number
## These Prime numbers are chosen arbitrarily by just testing => These are not perfect, repeats will appear in certain grids
func hash_cell(cell_x: int, cell_y: int) -> int:
	var a: int = cell_x * 16001 if sign(cell_x) != -1 else cell_x * 139999;
	var b: int = cell_y * 9737333 if sign(cell_y) != -1 else cell_y * 9599977;
	return abs(a + b);
