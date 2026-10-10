shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float aim_amount : hint_range(0.0, 1.0) = 0.0;
uniform float impact_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 slime_pixel = vec2(224.0, 224.0);
uniform vec2 aim_direction = vec2(1.0, 0.0);

void fragment() {
	vec3 room = texture(screen_texture, SCREEN_UV).rgb;
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 from_slime = pixel - slime_pixel;
	vec2 along_aim = aim_direction * clamp(dot(from_slime, aim_direction), 0.0, 42.0);
	float focus = 1.0 - smoothstep(14.0, 24.0, length(from_slime));
	float arrow = 1.0 - smoothstep(2.0, 5.0, length(from_slime - along_aim));
	float dim = aim_amount * (1.0 - max(focus, arrow));
	float gray = dot(room, vec3(0.299, 0.587, 0.114));
	room = mix(room, vec3(gray), dim * 0.38) * (1.0 - dim * 0.18);
	COLOR = vec4(mix(room, vec3(1.0), impact_flash), 1.0);
}
