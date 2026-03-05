// water_surface.gdshader
// Animated river water surface.
// Attach to a subdivided PlaneMesh (MeshInstance3D) positioned just above the salmon.
//
// Features:
//   - Animated wave normals (two scrolling layers)
//   - Translucency so fish are visible below
//   - Foam at edges / turbulence driven by swim_urgency uniform
//   - Caustic-like light shimmer on riverbed

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// --- Uniforms ---
uniform vec4 water_shallow : source_color = vec4(0.18, 0.42, 0.48, 0.72);
uniform vec4 water_deep    : source_color = vec4(0.05, 0.18, 0.28, 0.88);
uniform vec4 foam_color    : source_color = vec4(0.85, 0.90, 0.92, 1.0);

uniform float wave_speed   : hint_range(0.0, 2.0)  = 0.4;
uniform float wave_scale   : hint_range(0.1, 5.0)  = 1.8;
uniform float wave_height  : hint_range(0.0, 0.5)  = 0.06;
uniform float turbulence   : hint_range(0.0, 1.0)  = 0.2;  // driven by swim_urgency

// How much you can see through the water
uniform float transparency : hint_range(0.0, 1.0)  = 0.80;

// Fake caustics intensity
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.3;

uniform sampler2D noise_tex : hint_default_white, repeat_enable;

void vertex() {
	// Vertex displacement — gentle surface undulation
	vec2 uv1 = UV * wave_scale + vec2(TIME * wave_speed * 0.7, TIME * wave_speed * 0.3);
	vec2 uv2 = UV * wave_scale * 1.3 + vec2(-TIME * wave_speed * 0.4, TIME * wave_speed * 0.6);

	float n1 = texture(noise_tex, uv1).r;
	float n2 = texture(noise_tex, uv2).r;
	float displacement = (n1 + n2) * 0.5 - 0.5;

	VERTEX.y += displacement * wave_height * (1.0 + turbulence);
}

void fragment() {
	// Scrolling normal map layers for water ripples
	vec2 uv1 = UV * wave_scale + vec2(TIME * wave_speed * 0.6, TIME * wave_speed * 0.25);
	vec2 uv2 = UV * wave_scale * 1.4 + vec2(-TIME * wave_speed * 0.35, TIME * wave_speed * 0.55);

	vec3 n1 = texture(noise_tex, uv1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(noise_tex, uv2).rgb * 2.0 - 1.0;
	vec3 blended_normal = normalize(n1 + n2);
	NORMAL_MAP = blended_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2 + turbulence * 0.8;

	// Depth-based color blend (shallow edges lighter, deep center darker)
	float depth_factor = clamp(UV.y, 0.0, 1.0);
	vec4 water_col = mix(water_shallow, water_deep, depth_factor);

	// Caustic shimmer — fake with animated noise
	vec2 caustic_uv = UV * 3.5 + vec2(TIME * 0.15, TIME * 0.08);
	float caustics = texture(noise_tex, caustic_uv).r;
	caustics = pow(caustics, 3.0) * caustic_strength;

	// Foam at high turbulence
	float foam = smoothstep(0.6, 0.9, (n1.r + n2.r) * 0.5 + turbulence * 0.4);
	vec3 final_color = mix(water_col.rgb + caustics, foam_color.rgb, foam * turbulence);

	ALBEDO = final_color;
	ALPHA = water_col.a * (1.0 - transparency * 0.5);
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.9;
}
