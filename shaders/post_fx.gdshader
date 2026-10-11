shader_type canvas_item;
// Pós-processamento da atmosfera: dessaturação, contraste, matiz, neblina rasteira,
// granulação, vinheta, interferência por radiação e flash de dano.
// Parâmetros controlados por data/config/atmosphere.json (via scripts/ui/post_fx.gd).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float saturation = 0.62;
uniform float contrast = 1.08;
uniform vec4 tint : source_color = vec4(0.91, 0.93, 0.88, 1.0);
uniform float vignette = 0.55;
uniform float grain = 0.05;
uniform float fog = 0.2;
uniform vec4 fog_color : source_color = vec4(0.6, 0.64, 0.6, 1.0);
uniform float rad = 0.0;
uniform float hurt = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.82, 0.92, 0.98, 1.0);
uniform vec4 light_tint : source_color = vec4(1.06, 1.0, 0.88, 1.0);
uniform float dread = 0.0;      // 0..1: vida baixa / exposição alta / zona funda
uniform float pulse_rate = 1.1; // batimentos por segundo
uniform vec2 virtual_size = vec2(640.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float line = floor(uv.y * virtual_size.y);
	float glitch = step(1.0 - rad * 0.5, hash(vec2(floor(TIME * 12.0), floor(line / 6.0))));
	float jitter = (hash(vec2(line, floor(TIME * 20.0))) - 0.5) * 0.008 * rad * glitch;
	float ca = rad * 0.0011;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(jitter + ca, 0.0)).r;
	col.g = texture(screen_tex, uv + vec2(jitter, 0.0)).g;
	col.b = texture(screen_tex, uv + vec2(jitter - ca, 0.0)).b;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= tint.rgb;
	// gradação dividida: sombras frias, luzes quentes (sensação de filme, mais tensão)
	col *= mix(shadow_tint.rgb, light_tint.rgb, smoothstep(0.08, 0.62, lum));

	float n = noise(uv * vec2(3.0, 5.0) + vec2(TIME * 0.025, TIME * 0.008)) * 0.6
		+ noise(uv * vec2(8.0, 11.0) - vec2(TIME * 0.045, 0.0)) * 0.4;
	col = mix(col, fog_color.rgb * (0.35 + lum * 0.9), clamp(fog * n * (0.6 + uv.y * 0.6), 0.0, 1.0));

	vec2 px = floor(uv * virtual_size);
	col += (hash(px + fract(TIME) * 97.0) - 0.5) * grain * (1.0 + rad * 1.5);

	float st = hash(px + floor(TIME * 30.0) * 13.0);
	col = mix(col, vec3(0.55, 1.0, 0.45) * st, rad * 0.14 * step(0.95, st));

	vec2 d = uv - 0.5;
	float beat = pow(max(0.0, sin(TIME * 6.2832 * pulse_rate)), 12.0) * 0.6
		+ pow(max(0.0, sin(TIME * 6.2832 * pulse_rate - 0.9)), 14.0) * 0.4;
	float vig_r = 0.25 - dread * (0.10 + beat * 0.06);
	float v = smoothstep(0.85 - dread * 0.12, vig_r, length(d * vec2(1.0, 1.25)));
	col *= mix(1.0 - vignette - dread * 0.15, 1.0, v);
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), dread * 0.25 * (1.0 - v));
	col = mix(col, vec3(0.55, 0.04, 0.02), hurt * 0.4 * (1.0 - v * 0.6));
	COLOR = vec4(col, 1.0);
}
