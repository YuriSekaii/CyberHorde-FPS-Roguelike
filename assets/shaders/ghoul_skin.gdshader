shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Blood Ghoul skin: pitch-black hide carved with an ancient web of cracks that smoulder ember-red.
// The pattern lives in each part's object space so it sticks to the body as it moves.
uniform vec3 base_color : source_color = vec3(0.016, 0.014, 0.014);
uniform vec3 carve_color : source_color = vec3(0.07, 0.02, 0.016);
uniform vec3 vein_color : source_color = vec3(1.0, 0.07, 0.015);
uniform float pattern_scale = 11.0;
uniform float glow = 0.0; // 0 = dormant (hiding), 1 = fully awake; driven by blood_ghoul.gd
uniform float roughness_base = 0.62;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest Voronoi cell border (F2 - F1)
float cell_edge(vec3 x) {
	vec3 n = floor(x);
	vec3 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				vec3 r = g + hash3(n + g) - f;
				float d = dot(r, r);
				if (d < f1) {
					f2 = f1;
					f1 = d;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return sqrt(f2) - sqrt(f1);
}

void fragment() {
	vec3 p = obj_pos * pattern_scale;
	// Wide carved channels, with thin burning veins down their middle
	float edge = cell_edge(p);
	float fine = cell_edge(p * 2.3 + 17.0);
	float carve = 1.0 - smoothstep(0.03, 0.11, edge);
	float vein = (1.0 - smoothstep(0.0, 0.035, edge)) + (1.0 - smoothstep(0.0, 0.025, fine)) * 0.35;
	// Slow heartbeat crawling across the body
	float pulse = 0.65 + 0.35 * sin(TIME * 2.4 + obj_pos.y * 6.0);
	ALBEDO = mix(base_color, carve_color, carve);
	ROUGHNESS = mix(roughness_base, 0.3, carve);
	SPECULAR = 0.35;
	EMISSION = vein_color * clamp(vein, 0.0, 1.0) * glow * pulse * 1.6;
	RIM = 0.3;
	RIM_TINT = 0.25;
}
