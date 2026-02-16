shader_type canvas_item;

uniform vec3 tint_color : source_color = vec3(0.1, 0.1, 0.1);
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    float original_alpha = texture(TEXTURE, UV).a;
    COLOR = vec4(tint_color, original_alpha * alpha_multiplier);
}