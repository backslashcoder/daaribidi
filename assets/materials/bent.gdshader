shader_type spatial;
// "Bent world" shader: everything AHEAD of the player is pushed sideways/up by
// a quadratic curve, so a logically straight road LOOKS like it turns or climbs.
// Collisions stay straight, which keeps gameplay simple and fair.
// skip_vertex_transform lets us do the bend in world space ourselves.
render_mode skip_vertex_transform;

global uniform float bend_x;
global uniform float bend_y;
global uniform float bend_origin_z; // The player's Z; things behind it are not bent.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_linear;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ahead = max(0.0, bend_origin_z - world.z);
	world.x += bend_x * ahead * ahead;
	world.y += bend_y * ahead * ahead;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	ALBEDO = use_texture ? texture(albedo_texture, UV).rgb : albedo.rgb;
	ROUGHNESS = roughness;
}
