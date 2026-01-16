import SceneKit

/// Provides shader modifier code for advanced particle effects.
@available(iOS 15.0, macOS 12.0, *)
public struct ParticleShader {
    
    /// Geometry modifier for particle turbulence and life-based scaling
    public static let geometryModifier = """
    #pragma body
    
    // 1. Get particle life (0.0 to 1.0)
    float life = _geometry.texcoord0.x;
    
    // 2. Add some noise/turbulence based on time and position
    float noise = sin(u_time * 5.0 + _geometry.position.x * 10.0) * 0.1;
    _geometry.position.xyz += _geometry.normal * noise * (1.0 - life);
    
    // 3. Shrink particles as they die
    _geometry.position.xyz *= life;
    """
    
    /// Surface modifier for color gradients and blooming effects
    public static let surfaceModifier = """
    #pragma body
    
    // Use life for color gradients
    float life = _geometry.texcoord0.x;
    
    // Pulse intensity
    float pulse = sin(u_time * 10.0) * 0.5 + 0.5;
    
    // Enhance emission for a bloom-like effect
    _surface.emission.rgb = _surface.diffuse.rgb * (1.0 + pulse * life);
    _surface.transparent.a = life * life;
    """
}
