shader_type spatial;

// Uniforms for customization
uniform vec4 foreground_color : source_color = vec4(0.8, 0.3, 0.5, 1.0);
uniform vec4 background_color : source_color = vec4(0.3, 0.4, 0.6, 1.0);
uniform float level_depth : hint_range(1.0, 50.0) = 20.0;
uniform float noise_scale : hint_range(0.1, 5.0) = 1.0;
uniform float time_speed : hint_range(0.0, 2.0) = 0.5;

// Simple noise function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
    // Pass through vertex shader
}

void fragment() {
    // Get world position
    vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // Calculate depth factor based on Z position
    float depth_factor = (world_pos.z + level_depth * 0.5) / level_depth;
    depth_factor = clamp(depth_factor, 0.0, 1.0);
    
    // Add some noise for variation
    vec2 noise_coord = world_pos.xz * noise_scale + TIME * time_speed;
    float noise_value = noise(noise_coord) * 0.3;
    
    // Mix colors based on depth + noise
    float mix_factor = depth_factor + noise_value;
    mix_factor = clamp(mix_factor, 0.0, 1.0);
    
    vec3 final_color = mix(background_color.rgb, foreground_color.rgb, mix_factor);
    
    ALBEDO = final_color;
    METALLIC = 0.3;
    ROUGHNESS = 0.7;
}