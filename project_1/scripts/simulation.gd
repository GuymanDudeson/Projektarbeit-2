extends Node2D

@export var collision_damping : float = 1;
@export var bounds_size : Vector2 = Vector2(600, 400);
@export var particle_size : float = 20; 
@export var gravity : float = 980; 
@export var number_of_particles: int = 20;
@export var starting_density: int = 5;

var bounding_rectangle: Rect2 = Rect2(Vector2(position.x - bounds_size.x / 2, position.y - bounds_size.y / 2), Vector2(bounds_size.x, bounds_size.y));

var scene_to_instance = preload("res://scenes/water_drop.tscn")
var rng = RandomNumberGenerator.new();

func _ready() -> void:
	var squareSide = ceil(pow(number_of_particles, 1.0/2.0));
	var singleParticleSpace = (particle_size + starting_density);
	var squareOrigin = floor((squareSide / 2)) * -singleParticleSpace;
	var drawn = 0;
	for i in squareSide:
		for j in squareSide:
			if(drawn >= number_of_particles): continue;
			var x = squareOrigin + j * singleParticleSpace;
			var y = squareOrigin + i * singleParticleSpace;
			add_child(Water_Drop.new_water_drop(Vector2(x, y), collision_damping, bounding_rectangle, particle_size, gravity));
			drawn += 1;

func _process(delta: float) -> void:
	for i in self.get_children():
		if(i is CharacterBody2D):
			Global.densities[i.get_instance_id()] = Vector4(rng.randf_range(0,1), rng.randf_range(0,1), rng.randf_range(0,1), 1.0);
		

func _draw() -> void:
	draw_rect(bounding_rectangle, Color.WHEAT, false, 5);
	
