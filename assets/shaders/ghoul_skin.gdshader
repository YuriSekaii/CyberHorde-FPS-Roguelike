shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Blood Ghoul hide: pitch-black and cracked like old charred leather, splattered all over with its victims'
// blood: crusted patches, runs dribbling down, sprayed droplets, old blood caked into the cracks, and a few
// fresher patches that still glisten. The patterns live in each part's object space so they stick to the body.
uniform vec3 base_color : source_color = vec3(0.016, 0.014, 0.014);
uniform vec3 dry_blood : source_color = vec3(0.085, 0.012, 0.008);
uniform vec3 wet_blood : source_color = vec3(0.16, 0.006, 0.005);
uniform float pattern_scale = 11.0;
uniform float splatter_scale = 7.0;
uniform float splatter_amount = 0.5; // 0 = barely stained .. 1 = drenched
uniform float glow = 0.0; // 0 = dormant (hiding) .. 1 = hunting: the fresh blood catches more light. Driven by blood_ghoul.gd

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

float hash1(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash1(i), hash1(i + vec3(1, 0, 0)), f.x), mix(hash1(i + vec3(0, 1, 0)), hash1(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash1(i + vec3(0, 0, 1)), hash1(i + vec3(1, 0, 1)), f.x), mix(hash1(i + vec3(0, 1, 1)), hash1(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + 1.7;
		a *= 0.5;
	}
	return v / 0.9375;
}

// Distance to the nearest Voronoi cell border (F2 - F1): the hide's cracks
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

// Sprayed droplets: about half the cells hold a round spot of random size
float droplets(vec3 x) {
	vec3 n = floor(x);
	vec3 f = fract(x);
	float m = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				float size = hash1(n + g + 3.3);
				if (size > 0.5) {
					float rad = 0.08 + 0.22 * (size - 0.5);
					float d = length(g + hash3(n + g) - f);
					m = max(m, 1.0 - smoothstep(rad * 0.75, rad, d));
				}
			}
		}
	}
	return m;
}

void fragment() {
	float crack = 1.0 - smoothstep(0.02, 0.09, cell_edge(obj_pos * pattern_scale));
	vec3 q = obj_pos * splatter_scale;
	float bias = (splatter_amount - 0.5) * 0.25;
	// Crusted patches, runs stretched downward, and spray
	float patches = smoothstep(0.56, 0.6, fbm(q * 0.8 + vec3(3.1, 7.7, 1.3)) + bias);
	float runs = smoothstep(0.6, 0.63, fbm(vec3(q.x * 2.6, q.y * 0.35, q.z * 2.6) + 11.0) + bias);
	float spray = droplets(q * 2.5) * step(0.45, fbm(q * 0.5 + 40.0) + bias);
	float blood = max(max(patches, runs), spray);
	// Old blood settled into the cracks
	blood = max(blood, crack * 0.8 * smoothstep(0.4, 0.55, fbm(q * 1.7 + 5.0) + bias));
	float wet = blood * smoothstep(0.6, 0.66, fbm(q * 1.3 + 21.0));
	vec3 crust = dry_blood * (0.6 + 0.6 * vnoise(q * 9.0));
	vec3 skin = mix(base_color, base_color * 0.45, crack);
	ALBEDO = mix(skin, mix(crust, wet_blood, wet), blood);
	ROUGHNESS = mix(mix(0.62, 0.85, crack), mix(0.88, 0.12, wet), blood);
	SPECULAR = mix(0.35, mix(0.2, 0.75, wet), blood);
	// A faint dark-red glint so the gore still reads under the moon
	EMISSION = (dry_blood * 0.25 * (1.0 - wet) + wet_blood * wet * (0.3 + 0.5 * glow)) * blood;
	RIM = 0.3;
	RIM_TINT = 0.25;
}
