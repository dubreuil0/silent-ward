shader_type canvas_item;
// Tam ekran korku efektleri: film greni, vinyet, kromatik sapma,
// korku (fear) bozulması, hasar kızarması ve kararma.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float fear : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;
uniform float grain_amount = 0.055;
uniform float vignette_strength = 0.6;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float t = TIME;

	// korku dalgalanması
	uv += vec2(sin(uv.y * 23.0 + t * 3.1), cos(uv.x * 19.0 + t * 2.3)) * 0.0022 * fear;

	// yatay glitch bantları
	float band = floor(uv.y * 40.0);
	float gl = step(1.0 - glitch * 0.35, hash(vec2(band, floor(t * 24.0))));
	uv.x += (hash(vec2(band, t)) - 0.5) * 0.06 * gl;

	float ca = 0.0012 + 0.007 * fear + 0.01 * gl;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ca).b;

	// film greni
	float g = hash(uv * vec2(1931.0, 1173.0) + fract(t * 7.13) * 91.0) - 0.5;
	col += g * (grain_amount + fear * 0.05) * (0.6 + dot(col, vec3(0.33)));

	// tarama çizgisi titremesi
	col *= 0.985 + 0.015 * sin(SCREEN_UV.y * 900.0 + t * 30.0);

	// vinyet (korkuyla nabız gibi daralır)
	float pulse = 0.5 + 0.5 * sin(t * 7.0);
	float v = length(c * vec2(1.0, 1.2));
	float vig = smoothstep(0.85, 0.18 - fear * 0.1 * pulse, v * (1.0 + vignette_strength * 0.5 + fear * 0.45));
	col *= mix(1.0, vig, 0.9);

	// soğuk renk dengesi ve korkuyla doygunluk kaybı
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l) * vec3(0.92, 0.98, 1.05), 0.25 + fear * 0.35);

	// hasar / ölüm kızarması
	col = mix(col, vec3(l * 1.6, l * 0.15, l * 0.12) + vec3(0.12, 0.0, 0.0), damage);

	col = mix(col, vec3(0.0), blackout);
	COLOR = vec4(col, 1.0);
}
