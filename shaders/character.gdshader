shader_type spatial;
render_mode unshaded;

uniform float glow_intensity : hint_range(0.0, 5.0) = 1.3;
uniform float noise_scale : hint_range(0.01, 3.0) = 3.0; 
uniform float time_speed : hint_range(0.01, 1.0) = 1.0;
uniform vec3 base_color : source_color = vec3(0.0, 1.0, 0.0); // Зелений

// ---- Перлін шум ----
vec3 fade(vec3 t) {
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float lerp(float a, float b, float t) {
	return a + t * (b - a);
}

float grad(int hash, vec3 p) {
	int h = hash & 15;
	float u = h < 8 ? p.x : p.y;
	float v = h < 4 ? p.y : (h == 12 || h == 14 ? p.x : p.z);
	return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
}

// Штука для генерації псевдовипадкових чисел
int hash3D(ivec3 p) {
	return int(fract(sin(dot(vec3(p), vec3(12.9898, 78.233, 45.164))) * 43758.5453) * 256.0);
}

float perlin_noise(vec3 p) {
	ivec3 pi = ivec3(floor(p));
	vec3 pf = fract(p);
	vec3 f = fade(pf);

	float n000 = grad(hash3D(pi + ivec3(0, 0, 0)), pf - vec3(0, 0, 0));
	float n001 = grad(hash3D(pi + ivec3(0, 0, 1)), pf - vec3(0, 0, 1));
	float n010 = grad(hash3D(pi + ivec3(0, 1, 0)), pf - vec3(0, 1, 0));
	float n011 = grad(hash3D(pi + ivec3(0, 1, 1)), pf - vec3(0, 1, 1));
	float n100 = grad(hash3D(pi + ivec3(1, 0, 0)), pf - vec3(1, 0, 0));
	float n101 = grad(hash3D(pi + ivec3(1, 0, 1)), pf - vec3(1, 0, 1));
	float n110 = grad(hash3D(pi + ivec3(1, 1, 0)), pf - vec3(1, 1, 0));
	float n111 = grad(hash3D(pi + ivec3(1, 1, 1)), pf - vec3(1, 1, 1));

	float x1 = lerp(n000, n100, f.x);
	float x2 = lerp(n010, n110, f.x);
	float y1 = lerp(x1, x2, f.y);

	float x3 = lerp(n001, n101, f.x);
	float x4 = lerp(n011, n111, f.x);
	float y2 = lerp(x3, x4, f.y);

	return lerp(y1, y2, f.z) * 0.5 + 0.5;
}
// ---------------------

void fragment() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 noise_input = world_pos * noise_scale + vec3(TIME * time_speed);
	float n = perlin_noise(noise_input);
	//n = pow(n, 0.5);
	n = smoothstep(0.3, 0.6, n);
	// Формуємо кольоровий градієнт на основі шуму
	vec3 noise_color = vec3(n * 0.8, 1.0, 0.2 + 0.6 * (1.0 - n));  // Зелено-бірюзовий перелив

	// Мікс із основним кольором
	vec3 final_color = mix(base_color, noise_color, 0.5);

	ALBEDO = final_color;
	EMISSION = final_color * glow_intensity;
}
