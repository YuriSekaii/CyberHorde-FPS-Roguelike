shader_type canvas_item;

// progress: 0.0 = completely on cooldown (whole black), 1.0 = ready (regained full color)
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec4 cooldown_color : source_color = vec4(0.02, 0.02, 0.03, 0.98);
uniform vec4 border_color : source_color = vec4(0.0, 1.0, 0.7, 1.0);
uniform bool is_active = false;
uniform float pulse_time = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.01) {
		discard;
	}

	// Calculate angle around center (0.5, 0.5)
	// 12 o'clock (top) is 0.0, sweeping clockwise to 1.0
	vec2 dir = UV - vec2(0.5);
	float angle = atan(dir.x, -dir.y);
	if (angle < 0.0) {
		angle += 6.283185307179586;
	}
	float norm_angle = angle / 6.283185307179586; // 0.0 at top, increasing clockwise to 1.0

	if (is_active) {
		// Pulsing active effect
		float p = 0.75 + 0.25 * sin(pulse_time * 12.0);
		COLOR = vec4(mix(tex.rgb, border_color.rgb, 0.35 * p), tex.a);
	} else if (progress >= 0.999) {
		// Fully ready: original colors
		COLOR = tex;
	} else if (progress <= 0.001) {
		// Just entered cooldown: whole black
		COLOR = vec4(cooldown_color.rgb, tex.a * cooldown_color.a);
	} else {
		// In cooldown:
		// Part that has regained color: norm_angle <= progress
		if (norm_angle <= progress) {
			float sweep_edge = progress - norm_angle;
			if (sweep_edge >= 0.0 && sweep_edge < 0.018) {
				// Sleek bright sweep line at the leading edge
				COLOR = vec4(mix(tex.rgb, vec3(1.0), 0.75), tex.a);
			} else {
				COLOR = tex;
			}
		} else {
			// Part still in cooldown: whole black!
			COLOR = vec4(cooldown_color.rgb, tex.a * cooldown_color.a);
		}
	}
}
