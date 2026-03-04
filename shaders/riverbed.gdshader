// riverbed.gdshader
// Rocky riverbed with animated caustic light patterns from above.
// Attach to a flat PlaneMesh below the salmon school.

shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 rock_color_dark  : source_color = vec4(0.22, 0.20, 0.18, 1.0);
uniform vec4 rock_color_light : source_color = vec4(0.52, 0.48, 0.42, 1.0);
uniform vec4 caustic_tint     : source_color = vec4(0.4, 0.75, 0.8, 1.0);

uniform float rock_scale      : hint_range(0.5, 10.0) = 4.0;
uniform float caustic_speed   : hint_range(0.0, 1.0)  = 0.12;
uniform float caustic_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float turbulence      : hint_range(0.0, 1.0)  = 0.2;

uniform sampler2D noise_tex : hint_default_white, repeat_enable;

void fragment() {
	// Pebble/rock texture from layered noise
	vec2 rock_uv = UV * rock_scale;
	float n1 = texture(noise_tex, rock_uv).r;
	float n2 = texture(noise_tex, rock_uv * 2.3 + vec2(0.4, 0.7)).r;
	float n3 = texture(noise_tex, rock_uv * 0.5 + vec2(0.1, 0.3)).r;
	float rock_pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

	vec3 base_color = mix(rock_color_dark.rgb, rock_color_light.rgb, rock_pattern);

	// Animated caustics — two layers scrolling in different directions
	vec2 c_uv1 = UV * 2.5 + vec2(TIME * caustic_speed, TIME * caustic_speed * 0.6);
	vec2 c_uv2 = UV * 3.1 + vec2(-TIME * caustic_speed * 0.7, TIME * caustic_speed * 0.9);
	float c1 = texture(noise_tex, c_uv1).r;
	float c2 = texture(noise_tex, c_uv2).r;
	float caustics = pow((c1 + c2) * 0.5, 2.5) * caustic_intensity * (1.0 + turbulence);

	vec3 final_color = base_color + caustic_tint.rgb * caustics;

	ALBEDO = final_color;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
