import SceneKit

/// Provides shader modifier code for smooth sphere-to-plane morphing.
/// Following the research in 02_mathematical_foundations/sphere_to_plane_morphing.md
public struct MorphShader {
    
    /// Geometry modifier to interpolate vertex positions
    public static let geometryModifier = """
    uniform float u_mix;
    uniform float u_radius;

    #pragma body

    // 1. Convert initial spherical position to UV-like coordinates
    // We assume the geometry is a sphere of radius 1 centered at origin
    vec3 spherePos = _geometry.position.xyz;
    
    // Calculate polar coordinates
    float r = length(spherePos);
    float phi = atan(spherePos.z, spherePos.x); // Longitude range [-PI, PI]
    float theta = acos(spherePos.y / r);       // Latitude range [0, PI]

    // 2. Define Plane Position (Equirectangular)
    // Scale plane to match the sphere's circumference/height characteristics
    float planeX = phi * u_radius;
    float planeY = (3.14159/2.0 - theta) * u_radius;
    vec3 planePos = vec3(planeX, planeY, 0.0);

    // 3. Interpolate
    _geometry.position.xyz = mix(spherePos, planePos, u_mix);

    // 4. Handle Normals (Optional but better for lighting)
    vec3 sphereNormal = normalize(spherePos);
    vec3 planeNormal = vec3(0.0, 0.0, 1.0);
    _geometry.normal = mix(sphereNormal, planeNormal, u_mix);
    """
    
    /// Surface modifier for grid effects during transition
    public static let surfaceModifier = """
    uniform float u_mix;
    
    #pragma body
    
    // Add a simple grid effect that becomes more visible as we flatten
    vec2 grid = abs(fract(v_texcoord * 10.0) - 0.5);
    float line = smoothstep(0.48, 0.52, max(grid.x, grid.y));
    
    _surface.diffuse.rgb = mix(_surface.diffuse.rgb, vec3(0.0, 1.0, 1.0), line * u_mix * 0.5);
    """
}
