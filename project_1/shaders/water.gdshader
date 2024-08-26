shader_type particles;

uniform float gravity = 10;
uniform float collision_damping = 1;
uniform float boundsSize = 100;
uniform float particleSize = 3; 


void start() {
	// Called when a particle is spawned.
	TRANSFORM[0].x = particleSize;
	TRANSFORM[1].y = particleSize;
}

void resolve_collision(inout mat4 transform, inout vec3 velocity){
	vec2 halfBoundSize = boundsSize / 2.0 - vec2(1.0) * particleSize;
	
	if(abs(transform[3].x) > halfBoundSize.x){
		transform[3].x = halfBoundSize.x * sign(transform[3].x);
		velocity.x *= -1.0 * collision_damping;
	}
	
	if(abs(transform[3].y) > halfBoundSize.y){
		transform[3].y = halfBoundSize.y * sign(transform[3].y);
		velocity.y *= -1.0 * collision_damping;
	}
}

void process() {
	// Called every frame on existing particles (according to the Fixed FPS property).
	if(RESTART){
		VELOCITY.y += 0.1;
	} else {
		VELOCITY += vec3(0.0, 1.0, 0.0) * gravity * DELTA;
		resolve_collision(TRANSFORM, VELOCITY);
	}
}
