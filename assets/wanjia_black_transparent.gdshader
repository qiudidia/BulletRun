shader_type canvas_item;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	if (col.r < 0.05 && col.g < 0.05 && col.b < 0.05) {
		discard;
	}
	COLOR = col;
}
