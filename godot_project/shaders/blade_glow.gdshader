shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_add;

// Blade properties
uniform vec3 blade_color : source_color = vec3(0.2, 0.5, 1.0);
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float core_intensity : hint_range(0.0, 10.0) = 3.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float glow_falloff : hint_range(0.1, 5.0) = 2.0;

// Animation
uniform float extension : hint_range(0.0, 1.0) = 1.0;
uniform float flicker_speed : hint_range(0.0, 10.0) = 5.0;
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.05;

// Noise for subtle variation
uniform sampler2D noise_texture : hint_default_white;

varying vec3 local_vertex;
varying vec2 blade_uv;

void vertex() {
	local_vertex = VERTEX;

	// UV based on position along blade
	blade_uv = vec2(
		(VERTEX.x + 0.025) / 0.05,  // Normalized width
		(VERTEX.y + 0.5)             // Normalized length
	);

	// Scale blade based on extension (Y is along blade length)
	VERTEX.y *= extension;
}

void fragment() {
	// Distance from blade center axis (in XZ plane)
	float dist_from_center = length(local_vertex.xz) / 0.025;

	// Core brightness - brightest at center
	float core = 1.0 - smoothstep(0.0, 0.5, dist_from_center);
	core = pow(core, glow_falloff);

	// Outer glow falloff
	float outer_glow = 1.0 - smoothstep(0.3, 1.2, dist_from_center);

	// Sample noise for subtle flickering
	float time_offset = TIME * flicker_speed;
	vec2 noise_uv = blade_uv + vec2(time_offset * 0.1, 0.0);
	float noise = texture(noise_texture, noise_uv).r;
	float flicker = 1.0 + (noise - 0.5) * flicker_amount * 2.0;

	// Mix core and blade colors
	vec3 final_color = mix(blade_color, core_color, core * 0.8);

	// Apply intensity
	final_color *= (1.0 + core * core_intensity) * flicker;

	// Output
	ALBEDO = final_color;
	EMISSION = final_color * glow_intensity * flicker;

	// Alpha for edge softness
	ALPHA = outer_glow * extension;

	// Discard fully transparent pixels
	if (ALPHA < 0.01) {
		discard;
	}
}
