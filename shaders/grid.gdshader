shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform int columns : hint_range(1, 50) = 3;
uniform int rows    : hint_range(1, 50) = 3;
uniform float line_thickness_px : hint_range(1.0, 10.0) = 2.0; // pixels
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 bright_line_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // ligne sur fond clair
uniform vec4 dark_line_color   : source_color = vec4(1.0, 1.0, 1.0, 1.0); // ligne sur fond sombre

uniform vec2 rect_size = vec2(100.0, 100.0); // envoyé par script
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_nearest_mipmap;

void fragment() {
    vec2 uv = UV;

    // Taille d'une cellule en UV
    float cell_w = 1.0 / float(columns);
    float cell_h = 1.0 / float(rows);

    // Épaisseur en UV
    float thickness_x = line_thickness_px / rect_size.x;
    float thickness_y = line_thickness_px / rect_size.y;

    // Position relative dans la cellule
    float fx = mod(uv.x, cell_w);
    float fy = mod(uv.y, cell_h);

    bool near_vertical   = fx < thickness_x && uv.x > thickness_x;
    bool near_horizontal = fy < thickness_y && uv.y > thickness_y;

    if (near_vertical || near_horizontal) {
        // Récupère la couleur de l'image en dessous
        vec4 under_col = texture(SCREEN_TEXTURE, SCREEN_UV);
        float brightness = dot(under_col.rgb, vec3(0.299, 0.587, 0.114)); // luminance
		
		float contrast_factor = smoothstep(0.3, 0.7, brightness);

		vec4 line_color = mix(dark_line_color, bright_line_color, contrast_factor);

        COLOR = line_color;
    } else {
        COLOR = bg_color;
    }
}
