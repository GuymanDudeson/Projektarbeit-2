class_name Water_Drop
extends CharacterBody2D

const my_scene: PackedScene = preload("res://scenes/water_drop.tscn");

@export var starting_position: Vector2;

var sprite: Sprite2D;
var timer_accumulator = 0.0;

static func new_water_drop(startingPosition: Vector2) -> Water_Drop:
	var water_drop: Water_Drop = my_scene.instantiate();
	water_drop.starting_position = startingPosition;
	return water_drop;
	
func _on_ready() -> void:
	scale *= Global.particle_scale;
	position = starting_position;
	sprite = get_node("Sprite2D");
	
	## Necessary if you want to individually manipulate the material of a node.
	## By default Godot will not assign individual instances of a material to Node, but instead reference the same material in all of them.
	## A Color property for example will therefor be shared between all instances of the node if we don't duplicate.
	#var new_material_instance = sprite.material.duplicate();
	#sprite.set_material(new_material_instance);

#region PhysicsProcessing

func _physics_process(delta: float) -> void:
	if(!Global.simulate_physics): return;
	
	velocity += Vector2.DOWN * Global.gravity * delta;
	position += velocity * delta;
	
	#timer_accumulator += delta
	#if(timer_accumulator >= 1.0):
		#if(Global.densities.has(self.get_instance_id())):
			#sprite.material.set_shader_parameter("color", Global.densities[self.get_instance_id()]);
		#timer_accumulator = 0.0;
	
	resolve_collision();

func resolve_collision() -> void: 
	var bounds_adjusted = abs(Global.bounds_rectangle.position) - Vector2(1.0, 1.0) * Global.particle_scale;
	
	if(abs(position.x) > bounds_adjusted.x):
		position.x = bounds_adjusted.x * sign(position.x);
		velocity.x *= -1.0 * Global.collision_damping;
	
	if(abs(position.y) > bounds_adjusted.y):
		position.y = bounds_adjusted.y * sign(position.y);
		velocity.y *= -1.0 * Global.collision_damping;
		
#endregion
