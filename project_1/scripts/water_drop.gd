class_name Water_Drop
extends CharacterBody2D

const my_scene: PackedScene = preload("res://scenes/water_drop.tscn");

@export var collision_damping : float = 1;
@export var bounds_size : Rect2;
@export var particle_size : float = 3; 
@export var gravity: float = 980;
@export var starting_position: Vector2 = Vector2(0, 0);

var sprite: Sprite2D;

static func new_water_drop(startingPosition: Vector2, collisionDamping: float, boundsSize : Rect2, particleSize: float, gravity: float) -> Water_Drop:
	var new_water_drop: Water_Drop = my_scene.instantiate();
	new_water_drop.collision_damping = collisionDamping;
	new_water_drop.bounds_size = boundsSize;
	new_water_drop.particle_size = particleSize;
	new_water_drop.starting_position = startingPosition;
	return new_water_drop;
	
func _on_sprite_2d_ready() -> void:
	scale *= particle_size;
	position = starting_position;
	sprite = get_node("Sprite2D");

func resolve_collision() -> void: 
	var bounds_adjusted = abs(bounds_size.position) - Vector2(1.0, 1.0) * particle_size;
	
	if(abs(position.x) > bounds_adjusted.x):
		position.x = bounds_adjusted.x * sign(position.x);
		velocity.x *= -1.0 * collision_damping;
	
	if(abs(position.y) > bounds_adjusted.y):
		position.y = bounds_adjusted.y * sign(position.y);
		velocity.y *= -1.0 * collision_damping;

func _physics_process(delta: float) -> void:
	velocity += Vector2.DOWN * gravity * delta;
	position += velocity * delta;
	if(Global.densities.has(self.get_instance_id())):
		sprite.material.set_shader_parameter("color", Global.densities[self.get_instance_id()]);
	resolve_collision();
