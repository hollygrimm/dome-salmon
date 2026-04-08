// riverbed.gdshader
// Rocky riverbed with animated caustic light patterns from above.
// Attach to a flat PlaneMesh below the salmon school.

shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 rock_color_dark  : source_color = vec4(0.22, 0.20, 0.18, 1.0);
uniform vec4 rock_color_light : source_color = vec4(0.52, 0.48, 0.42, 1.0);
uniform vec4 bank_color       : source_color = vec4(0.62, 0.55, 0.42, 1.0);
uniform vec4 channel_color    : source_color = vec4(0.10, 0.13, 0.15, 1.0);
uniform vec4 caustic_tint     : source_color = vec4(0.4, 0.75, 0.8, 1.0);

uniform float rock_scale      : hint_range(0.5, 10.0) = 4.0;
uniform float caustic_speed   : hint_range(0.0, 1.0)  = 0.12;
uniform float caustic_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float turbulence      : hint_range(0.0, 1.0)  = 0.2;

// ── Procedural channel carve ────────────────────────────────────────────────
// Sine meander matching Main.gd's RiverPath. Tweak if you change the path
// generation params there.
uniform float channel_amplitude_uv : hint_range(0.0, 0.5)  = 0.149;  // 5m / 33.6m plane width
uniform float channel_half_width_uv : hint_range(0.01, 0.5) = 0.238; // 8m / 33.6m
uniform float channel_waves         : hint_range(0.0, 6.0)  = 2.5;
uniform float channel_depth_strength : hint_range(0.0, 1.0) = 0.85;
uniform float bank_falloff           : hint_range(0.5, 4.0) = 1.6;

uniform sampler2D noise_tex : hint_default_white, repeat_enable;

void fragment() {
	// Pebble/rock texture from layered noise
	vec2 rock_uv = UV * rock_scale;
	float n1 = texture(noise_tex, rock_uv).r;
	float n2 = texture(noise_tex, rock_uv * 2.3 + vec2(0.4, 0.7)).r;
	float n3 = texture(noise_tex, rock_uv * 0.5 + vec2(0.1, 0.3)).r;
	float rock_pattern = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;

	vec3 base_color = mix(rock_color_dark.rgb, rock_color_light.rgb, rock_pattern);

	// ── Channel carve ──────────────────────────────────────────────────────
	// Compute distance from this fragment to the meandering channel centerline
	// in UV space. The centerline is a sine wave of UV.y, mirroring the
	// procedural Path3D built in Main.gd.
	float u_centered = UV.x - 0.5;
	float channel_center_u = sin(UV.y * PI * channel_waves) * channel_amplitude_uv;
	float dist_to_channel = abs(u_centered - channel_center_u);

	// 0 = inside channel, 1 = far on the bank
	float bank_factor = clamp(dist_to_channel / channel_half_width_uv, 0.0, 1.0);
	bank_factor = pow(bank_factor, bank_falloff);

	// Inside the channel: darker, deeper-water bed
	vec3 channel_bed = mix(channel_color.rgb, base_color, 0.25);
	// On the banks: drier, lighter substrate
	vec3 bank_bed = mix(base_color, bank_color.rgb, 0.6);

	base_color = mix(channel_bed, bank_bed, bank_factor);

	// Animated caustics — two layers scrolling in different directions.
	// Strongest in the channel where the water column is deepest.
	vec2 c_uv1 = UV * 2.5 + vec2(TIME * caustic_speed, TIME * caustic_speed * 0.6);
	vec2 c_uv2 = UV * 3.1 + vec2(-TIME * caustic_speed * 0.7, TIME * caustic_speed * 0.9);
	float c1 = texture(noise_tex, c_uv1).r;
	float c2 = texture(noise_tex, c_uv2).r;
	float caustics = pow((c1 + c2) * 0.5, 2.5) * caustic_intensity * (1.0 + turbulence);
	caustics *= mix(1.0, 0.2, bank_factor);  // fade caustics on dry banks

	vec3 final_color = base_color + caustic_tint.rgb * caustics;

	// Subtle deepening toward channel center based on depth strength
	final_color *= mix(1.0 - channel_depth_strength * 0.4, 1.0, bank_factor);

	ALBEDO = final_color;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
