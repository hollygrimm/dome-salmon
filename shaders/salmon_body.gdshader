// salmon_body.gdshader
// Vertex shader: sine-wave undulation propagating tail→head.
// Attach to the salmon mesh material (StandardMaterial3D > Next Pass, or ShaderMaterial).
//
// Parameters exposed to Inspector:
//   undulation_speed    — how fast the wave travels (tied to swim speed)
//   undulation_amplitude — side-to-side swing magnitude
//   wave_frequency      — number of full waves along body length

shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// --- Uniforms (set from GDScript or Inspector) ---
uniform float undulation_speed : hint_range(0.5, 10.0) = 3.0;
uniform float undulation_amplitude : hint_range(0.0, 0.3) = 0.08;
uniform float wave_frequency : hint_range(0.5, 4.0) = 1.5;
uniform float phase_offset : hint_range(0.0, 6.28) = 0.0;  // per-instance, set via INSTANCE_CUSTOM

// --- Visual ---
uniform vec4 base_color : source_color = vec4(0.6, 0.25, 0.15, 1.0);
uniform vec4 belly_color : source_color = vec4(0.85, 0.75, 0.65, 1.0);
// Spawning red coloration (driven by vertical_energy param)
uniform float spawn_color_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 spawn_color : source_color = vec4(0.75, 0.15, 0.1, 1.0);

uniform sampler2D texture_albedo : source_color, hint_default_white;

void vertex() {
	// UV.y = 0 at tail, 1 at nose (assumes mesh UV is laid out this way)
	// Tail swings more than head — envelope tapers toward nose
	float tail_envelope = 1.0 - UV.y;
	tail_envelope = pow(tail_envelope, 1.5);  // nonlinear taper

	float wave = sin(
		UV.y * wave_frequency * TAU
		- TIME * undulation_speed
		+ phase_offset
	);

	VERTEX.x += wave * undulation_amplitude * tail_envelope;
}

void fragment() {
	// Vertical gradient: base color on back, belly color underneath
	float belly_mask = clamp(1.0 - UV.y * 2.0, 0.0, 1.0);
	vec4 body_col = mix(base_color, belly_color, belly_mask);

	// Spawning coloration overlay (flanks turn red/pink)
	body_col = mix(body_col, spawn_color, spawn_color_amount * (1.0 - belly_mask));

	// Fake scale pattern — high-frequency stripes along body length,
	// modulates roughness so light catches differently across flanks.
	float scales = sin(UV.y * 180.0) * sin(UV.x * 120.0);
	float scale_mask = 0.5 + 0.5 * scales;

	ALBEDO = body_col.rgb * texture(texture_albedo, UV).rgb;
	// Wetter/rougher on the back, smoother on the belly; scales add variance.
	ROUGHNESS = mix(0.65, 0.45, belly_mask) + scale_mask * 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.35;

	// Fresnel rim — wet sheen where light grazes the body edge.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO += vec3(0.25, 0.32, 0.38) * fresnel * 0.4;
}
