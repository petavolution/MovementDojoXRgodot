shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Trail properties
uniform vec3 trail_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float trail_width : hint_range(0.001, 0.1) = 0.02;
uniform float fade_length : hint_range(0.0, 1.0) = 1.0;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.0;

// Animation
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.1;

varying float age_factor;  // 0 = newest, 1 = oldest

void vertex() {
	// Age factor passed via vertex color or UV
	age_factor = UV.y;  // Assuming Y UV encodes age

	// Pulse animation
	float pulse = sin(TIME * pulse_speed + age_factor * 3.14159) * pulse_amount;
	float width_scale = 1.0 + pulse;

	// Fade width for older parts
	width_scale *= (1.0 - age_factor * 0.5);

	// Apply width scaling (assuming trail is built along X axis for width)
	VERTEX.x *= width_scale;
}

void fragment() {
	// Fade based on age
	float alpha = 1.0 - pow(age_factor, fade_length);

	// Edge softness
	float edge = abs(UV.x - 0.5) * 2.0;
	float edge_fade = 1.0 - smoothstep(0.7, 1.0, edge);

	// Final color
	vec3 final_color = trail_color * (1.0 + (1.0 - age_factor) * 0.5);

	ALBEDO = final_color;
	EMISSION = final_color * glow_intensity * (1.0 - age_factor);
	ALPHA = alpha * edge_fade;

	if (ALPHA < 0.01) {
		discard;
	}
}
