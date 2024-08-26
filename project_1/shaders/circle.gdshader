shader_type canvas_item;

uniform vec4 color = vec4(0.2, 0.5, 0.9, 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

	// Called for every pixel the material is visible on.
void fragment() {
	// A Vector with all subdivisions of this pixel
	float dist = length(UV - vec2(0.5, 0.5));
	if(dist < 0.5){
		COLOR = color;
	} else {
		discard;
	}
}
