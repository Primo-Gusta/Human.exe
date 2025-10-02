shader_type canvas_item;

uniform float scroll_speed = 0.1; // Velocidade do scroll

void fragment() {
    // Pega as coordenadas UV da textura e adiciona o tempo ao eixo Y
    vec2 scrolling_uv = UV;
    scrolling_uv.y -= TIME * scroll_speed;
    
    // Pega a cor da textura na nova posição e aplica à tela
    COLOR = texture(TEXTURE, scrolling_uv);
}