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

func position_to_cell_coord(point: Vector2i, radius: float) -> Vector2i:
	var cell_x: int = ceil(point.x / radius);
	var cell_y: int = ceil(point.y / radius);
	return Vector2(cell_x, cell_y);


func hash_cell(cell_x: int, cell_y: int) -> int:
	var a: int = cell_x * 15823;
	var b: int = cell_y * 9737333;
	return abs(a + b);
	
func get_key_from_hash(input_hash: int) -> int:
	return input_hash % Global.spatial_lookup.size();
