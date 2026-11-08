shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Hemşire yaratığı için prosedürel deri / kumaş shader'ı.
// is_cloth = 0: ıslak, damarlı solgun deri. is_cloth = 1: kirli, kanlı önlük.

uniform float is_cloth = 0.0;
uniform vec3 base_a : source_color = vec3(0.56, 0.55, 0.5);
uniform vec3 base_b : source_color = vec3(0.24, 0.25, 0.26);
uniform vec3 blood : source_color = vec3(0.22, 0.015, 0.01);
uniform float blood_amount = 0.35;
uniform float bottom_blood = 0.0;
uniform float glitch = 0.0;
uniform float rim_strength = 0.12;

varying vec3 lp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	lp = VERTEX;
	float tick = floor(TIME * 18.0);
	float g = glitch * step(0.9, hash(vec3(tick, floor(VERTEX.y * 10.0), 3.0)));
	VERTEX += NORMAL * g * 0.05;
	VERTEX.x += g * (hash(vec3(tick, 1.0, 7.0)) - 0.5) * 0.08;
}

void fragment() {
	vec3 p = lp * 6.0;
	float n = fbm(p);
	vec3 col = mix(base_a, base_b, smoothstep(0.3, 0.8, n));
	float rough;
	if (is_cloth < 0.5) {
		float veins = 1.0 - smoothstep(0.0, 0.035, abs(fbm(lp * 4.0 + 11.0) - 0.5));
		col = mix(col, vec3(0.12, 0.16, 0.24), veins * 0.55);
		float rot = smoothstep(0.55, 0.75, fbm(lp * 3.0 + 3.0));
		col = mix(col, vec3(0.18, 0.2, 0.12), rot * 0.5);
		rough = 0.32 - 0.12 * n;
		SSS_STRENGTH = 0.25;
	} else {
		float folds = 0.5 + 0.5 * sin(lp.x * 40.0 + fbm(lp * 8.0) * 6.0);
		col *= 0.85 + 0.15 * folds;
		float dirt = smoothstep(0.45, 0.8, fbm(lp * 5.0 + 5.0));
		col = mix(col, vec3(0.28, 0.22, 0.15), dirt * 0.6);
		rough = 0.88;
	}
	float b = smoothstep(1.0 - blood_amount, 1.0 - blood_amount + 0.12, fbm(lp * 3.5 + 21.0) + bottom_blood * smoothstep(0.1, -0.5, lp.y));
	col = mix(col, blood, b);
	rough = mix(rough, 0.18, b);

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.55;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.06, 0.08, 0.1) * rim * rim_strength * 6.0;
}
