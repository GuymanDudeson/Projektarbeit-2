shader_type canvas_item;

uniform float border_thickness_px = 5.0;
uniform vec2 rect_size = vec2(400.0, 400.0);
uniform vec4 border_color = vec4(0.8, 0.5, 0.5, 0.8);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 pixel_pos = UV * rect_size;
	
	if(pixel_pos.x <= border_thickness_px || pixel_pos.y <= border_thickness_px || pixel_pos.x >= rect_size.x - border_thickness_px || pixel_pos.y >= rect_size.y - border_thickness_px){
		COLOR = border_color;
	} else {
		discard;
	}
}
