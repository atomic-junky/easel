shader_type canvas_item;

uniform vec2 mask_pos;   // Position globale du slider
uniform vec2 mask_size;  // Taille du slider
uniform float corner_radius = 10.0; // Rayon des coins arrondis

void fragment() {
    vec2 half_size = mask_size * 0.5;
    vec2 center = mask_pos + half_size;

    // Distance depuis le centre (pour la forme)
    vec2 p = abs(FRAGCOORD.xy - center) - (half_size - vec2(corner_radius));
    float dist = length(max(p, 0.0)) - corner_radius;

    // Si dist < 0 → on est dans la zone du trou
    float mask = step(0.0, dist);

    // Noir transparent dans le trou, noir opaque ailleurs
    COLOR = vec4(0.0, 0.0, 0.0, mask);
}
