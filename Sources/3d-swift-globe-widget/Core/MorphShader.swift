import SceneKit

/// Provides shader modifier code for smooth sphere-to-plane morphing.
/// Enhanced for Stage 2: Advanced morphing with grid effects and rim lighting
/// Following the research in 02_mathematical_foundations/sphere_to_plane_morphing.md
public struct MorphShader {
    
    /// Geometry modifier to interpolate vertex positions
    /// Stage 2: Enhanced with smooth transitions and proper UV mapping
    public static let geometryModifier = """
    uniform float u_mix;
    uniform float u_radius;
    uniform float u_time; // Stage 2: Time-based animations

    #pragma body

    // 1. Convert initial spherical position to UV-like coordinates
    // We assume the geometry is a sphere of radius 1 centered at origin
    vec3 spherePos = _geometry.position.xyz;
    
    // Calculate polar coordinates with enhanced precision
    float r = length(spherePos);
    float phi = atan(spherePos.z, spherePos.x); // Longitude range [-PI, PI]
    float theta = acos(spherePos.y / r);       // Latitude range [0, PI]
    
    // Stage 2: Add subtle animation during morphing
    float morphAnimation = sin(u_time * 2.0) * 0.02 * u_mix;

    // 2. Define Plane Position (Equirectangular projection)
    // Scale plane to match the sphere's circumference/height characteristics
    float planeX = phi * u_radius + morphAnimation;
    float planeY = (3.14159/2.0 - theta) * u_radius;
    vec3 planePos = vec3(planeX, planeY, 0.0);

    // 3. Smooth interpolation with easing function
    float easedMix = smoothstep(0.0, 1.0, u_mix);
    _geometry.position.xyz = mix(spherePos, planePos, easedMix);

    // 4. Enhanced normal calculation for proper lighting
    vec3 sphereNormal = normalize(spherePos);
    vec3 planeNormal = vec3(0.0, 0.0, 1.0);
    _geometry.normal = mix(sphereNormal, planeNormal, easedMix);
    
    // Stage 2: Pass UV coordinates to fragment shader
    vec2 uv = vec2((phi + 3.14159) / (2.0 * 3.14159), theta / 3.14159);
    _geometry.texcoords[0] = uv;
    """
    
    /// Surface modifier for grid effects and enhanced visuals during transition
    /// Stage 2: Advanced grid rendering with rim lighting and animated effects
    public static let surfaceModifier = """
    uniform float u_mix;
    uniform float u_time;
    uniform float u_radius;

    #pragma body
    
    // Stage 2: Enhanced grid effect with animation
    vec2 uv = _surface.texcoords[0];
    vec2 grid = abs(fract(uv * 20.0) - 0.5); // Higher resolution grid
    float line = smoothstep(0.48, 0.52, max(grid.x, grid.y));
    
    // Stage 2: Animated grid intensity during morph
    float animatedLine = line * (0.5 + 0.5 * sin(u_time * 3.0));
    
    // Stage 2: Enhanced rim lighting calculation
    vec3 viewDirection = normalize(_surface.view);
    vec3 normal = normalize(_surface.normal);
    float fresnel = 1.0 - abs(dot(viewDirection, normal));
    float rim = pow(fresnel, 2.0);
    
    // Stage 2: Color transitions based on morph state
    vec3 gridColor = mix(vec3(0.0, 0.8, 1.0), vec3(0.0, 1.0, 0.8), u_mix);
    vec3 rimColor = mix(vec3(0.0, 0.5, 1.0), vec3(1.0, 0.5, 0.0), u_mix);
    
    // Stage 2: Combine effects with proper blending
    vec3 finalColor = _surface.diffuse.rgb;
    finalColor = mix(finalColor, gridColor, animatedLine * u_mix * 0.8);
    finalColor += rimColor * rim * 0.6 * u_mix;
    
    // Stage 2: Add subtle pulsing effect
    float pulse = sin(u_time * 4.0) * 0.1 + 0.9;
    finalColor *= pulse;
    
    _surface.diffuse.rgb = finalColor;
    
    // Stage 2: Enhanced emissive glow during morph
    _surface.emission.rgb = rimColor * rim * u_mix * 0.3;
    """
    
    // Stage 2: Additional shader for vertex displacement effects
    public static let displacementModifier = """
    uniform float u_time;
    uniform float u_mix;
    
    #pragma body
    
    // Stage 2: Subtle vertex displacement during morph
    if (u_mix > 0.01 && u_mix < 0.99) {
        float displacement = sin(_geometry.position.x * 10.0 + u_time * 2.0) * 
                           sin(_geometry.position.y * 10.0 + u_time * 2.0) * 
                           0.01 * u_mix;
        _geometry.position.xyz += _geometry.normal * displacement;
    }
    """
}
