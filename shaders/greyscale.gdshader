shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
    COLOR = texture(screen_texture, SCREEN_UV);
    float avg = (COLOR.r + COLOR.g + COLOR.b) / 3.0;
    COLOR.rgb = vec3(avg);
}