#include <metal_stdlib>
using namespace metal;

// MARK: - Data Structures

struct Particle {
    float3 position;
    float3 velocity;
    float life;
    float size;
    float3 color;
    uint pattern;
    float intensity;
};

struct SimulationUniforms {
    float deltaTime;
    float time;
    float3 gravity;
    float damping;
    float noiseScale;
    float noiseSpeed;
    uint particleCount;
    uint maxParticles;
    uint frameCount;
};

struct EmissionUniforms {
    float3 emitPosition;
    uint pattern;
    float intensity;
    uint particleCount;
    float3 baseColor;
    float baseSize;
};

struct CullingUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix;
    float3 cameraPosition;
    float farPlane;
    float frustumPadding;
};

struct VertexOut {
    float4 position [[position]];
    float3 color;
    float life;
    float size;
    float pointSize [[point_size]];
};

// MARK: - Noise Functions

/// Improved 3D simplex noise implementation
/// TODO: Replace with optimized gradient noise for better performance
float3 simplexNoise3D(float3 p, float time) {
    float3 s = floor(p + dot(p, float3(0.3333333, 0.3333333, 0.3333333)));
    float3 x = p - s + dot(s, float3(0.1666667, 0.1666667, 0.1666667));
    
    float3 e = step(float3(0.0), x - x.yzx);
    float3 i1 = e * (1.0 - e.zxy);
    float3 i2 = 1.0 - e.zxy * (1.0 - e);
    
    float3 x1 = x - i1 + 0.1666667;
    float3 x2 = x - i2 + 0.3333333;
    float3 x3 = x - 0.5;
    
    float4 w = float4(x.x, x.y, x.z, 1.0) - float4(x1.x, x1.y, x1.z, 1.0) - 
               float4(x2.x, x2.y, x2.z, 1.0) - float4(x3.x, x3.y, x3.z, 1.0);
    w = max(w, 0.0);
    w = w * w * w * w;
    
    float4 s0 = float4(0.0, 0.0, 0.0, 1.0) + float4(x.x, x.y, x.z, 1.0);
    float4 s1 = float4(0.0, 0.0, 0.0, 1.0) + float4(x1.x, x1.y, x1.z, 1.0);
    float4 s2 = float4(0.0, 0.0, 0.0, 1.0) + float4(x2.x, x2.y, x2.z, 1.0);
    float4 s3 = float4(0.0, 0.0, 0.0, 1.0) + float4(x3.x, x3.y, x3.z, 1.0);
    
    float4 n0 = float4(dot(s0, float4(sin(time * 0.1), sin(time * 0.2), sin(time * 0.3), 1.0)),
                       dot(s0, float4(cos(time * 0.4), cos(time * 0.5), cos(time * 0.6), 1.0)),
                       dot(s0, float4(sin(time * 0.7), sin(time * 0.8), sin(time * 0.9), 1.0)),
                       dot(s0, float4(cos(time * 1.0), cos(time * 1.1), cos(time * 1.2), 1.0)));
    
    float4 n1 = float4(dot(s1, float4(sin(time * 0.13), sin(time * 0.23), sin(time * 0.33), 1.0)),
                       dot(s1, float4(cos(time * 0.43), cos(time * 0.53), cos(time * 0.63), 1.0)),
                       dot(s1, float4(sin(time * 0.73), sin(time * 0.83), sin(time * 0.93), 1.0)),
                       dot(s1, float4(cos(time * 1.03), cos(time * 1.13), cos(time * 1.23), 1.0)));
    
    float4 n2 = float4(dot(s2, float4(sin(time * 0.16), sin(time * 0.26), sin(time * 0.36), 1.0)),
                       dot(s2, float4(cos(time * 0.46), cos(time * 0.56), cos(time * 0.66), 1.0)),
                       dot(s2, float4(sin(time * 0.76), sin(time * 0.86), sin(time * 0.96), 1.0)),
                       dot(s2, float4(cos(time * 1.06), cos(time * 1.16), cos(time * 1.26), 1.0)));
    
    float4 n3 = float4(dot(s3, float4(sin(time * 0.19), sin(time * 0.29), sin(time * 0.39), 1.0)),
                       dot(s3, float4(cos(time * 0.49), cos(time * 0.59), cos(time * 0.69), 1.0)),
                       dot(s3, float4(sin(time * 0.79), sin(time * 0.89), sin(time * 0.99), 1.0)),
                       dot(s3, float4(cos(time * 1.09), cos(time * 1.19), cos(time * 1.29), 1.0)));
    
    float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, float4(n0,n1,n2,n3));
}

/// Optimized curl noise calculation
float3 curlNoise(float3 position, float time, float scale) {
    float3 p = position * scale;
    float eps = 0.01;
    
    // Calculate noise gradients
    float3 dx = float3(eps, 0.0, 0.0);
    float3 dy = float3(0.0, eps, 0.0);
    float3 dz = float3(0.0, 0.0, eps);
    
    float n1 = simplexNoise3D(p + dx, time).y - simplexNoise3D(p - dx, time).y;
    float n2 = simplexNoise3D(p + dy, time).x - simplexNoise3D(p - dy, time).x;
    float n3 = simplexNoise3D(p + dz, time).y - simplexNoise3D(p - dz, time).y;
    float n4 = simplexNoise3D(p + dx, time).z - simplexNoise3D(p - dx, time).z;
    float n5 = simplexNoise3D(p + dz, time).x - simplexNoise3D(p - dz, time).x;
    float n6 = simplexNoise3D(p + dy, time).z - simplexNoise3D(p - dy, time).z;
    
    return float3(n6 - n3, n4 - n5, n1 - n2) / (2.0 * eps);
}

// MARK: - Pattern Functions

/// Generates explosive burst pattern
float3 explosivePattern(uint id, uint total, float intensity, float time) {
    // Fibonacci sphere distribution for uniform explosion
    float phi = 3.14159265 * (3.0 - sqrt(5.0)); // Golden angle
    float y = 1.0 - (float(id) / float(total - 1)) * 2.0; // -1 to 1
    float radius = sqrt(1.0 - y * y);
    float theta = phi * float(id);
    
    float3 direction = float3(cos(theta) * radius, y, sin(theta) * radius);
    float velocity = (fract(sin(id * 12.9898) * 43758.5453) * 0.5 + 0.5) * intensity * 5.0;
    
    return direction * velocity;
}

/// Generates fountain burst pattern
float3 fountainPattern(uint id, uint total, float intensity, float time) {
    float t = float(id) / float(total);
    float angle = t * 2.0 * 3.14159;
    float spread = 0.5;
    
    float3 direction = float3(
        sin(angle) * spread,
        1.0,
        cos(angle) * spread
    );
    
    float velocity = (fract(sin(id * 78.233) * 43758.5453) * 0.5 + 0.5) * intensity * 8.0;
    
    return direction * velocity;
}

/// Generates spiral burst pattern
float3 spiralPattern(uint id, uint total, float intensity, float time) {
    float t = float(id) / float(total);
    float spiralTurns = 3.0;
    float angle = t * spiralTurns * 2.0 * 3.14159;
    float radius = t * 0.1;
    
    float3 direction = float3(
        cos(angle) * radius,
        t,
        sin(angle) * radius
    );
    
    float velocity = (1.0 - t) * 4.0 * intensity;
    
    return normalize(direction) * velocity;
}

/// Generates shockwave burst pattern
float3 shockwavePattern(uint id, uint total, float intensity, float time) {
    uint rings = 5;
    uint particlesPerRing = total / rings;
    uint ring = id / particlesPerRing;
    uint ringIndex = id % particlesPerRing;
    
    float angle = float(ringIndex) * 2.0 * 3.14159 / float(particlesPerRing);
    float ringRadius = float(ring + 1) * 0.05;
    
    float3 direction = float3(cos(angle), 0.0, sin(angle));
    float velocity = (float(rings - ring) * 0.5) * intensity * 2.0;
    
    return direction * velocity;
}

// MARK: - Compute Shaders

/// Main particle physics simulation kernel
kernel void particlePhysics(
    device Particle* particles [[buffer(0)]],
    constant SimulationUniforms& uniforms [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= uniforms.particleCount) return;
    
    device Particle& particle = particles[id];
    
    // Skip dead particles
    if (particle.life <= 0.0) return;
    
    // Apply curl noise for fluid motion
    float3 noiseForce = curlNoise(particle.position, uniforms.time, uniforms.noiseScale);
    particle.velocity += noiseForce * uniforms.deltaTime;
    
    // Apply gravity
    particle.velocity += uniforms.gravity * uniforms.deltaTime;
    
    // Apply damping
    particle.velocity *= uniforms.damping;
    
    // Update position
    particle.position += particle.velocity * uniforms.deltaTime;
    
    // Update life
    particle.life -= uniforms.deltaTime * 0.5;
    
    // Update color based on life
    particle.color *= particle.life;
}

/// Particle emission kernel for burst patterns
kernel void emitBurst(
    device Particle* particles [[buffer(0)]],
    constant SimulationUniforms& uniforms [[buffer(1)]],
    constant EmissionUniforms& emission [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= emission.particleCount || id >= uniforms.maxParticles) return;
    
    device Particle& particle = particles[id];
    
    // Initialize particle
    particle.position = emission.emitPosition;
    particle.life = 1.0;
    particle.size = emission.baseSize * (fract(sin(id * 12.9898) * 43758.5453) * 0.5 + 0.5);
    particle.pattern = emission.pattern;
    particle.intensity = emission.intensity;
    particle.color = emission.baseColor;
    
    // Generate pattern-specific velocity
    switch (emission.pattern) {
        case 0: // Explosive
            particle.velocity = explosivePattern(id, emission.particleCount, emission.intensity, uniforms.time);
            break;
        case 1: // Fountain
            particle.velocity = fountainPattern(id, emission.particleCount, emission.intensity, uniforms.time);
            break;
        case 2: // Spiral
            particle.velocity = spiralPattern(id, emission.particleCount, emission.intensity, uniforms.time);
            break;
        case 3: // Shockwave
            particle.velocity = shockwavePattern(id, emission.particleCount, emission.intensity, uniforms.time);
            break;
        default:
            particle.velocity = float3(0.0);
            break;
    }
}

/// Particle culling kernel for performance optimization
kernel void cullParticles(
    device Particle* particles [[buffer(0)]],
    device uint* visibleIndices [[buffer(1)]],
    device atomic_uint* visibleCount [[buffer(2)]],
    constant SimulationUniforms& uniforms [[buffer(3)]],
    constant CullingUniforms& culling [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= uniforms.particleCount) return;
    
    device Particle& particle = particles[id];
    
    // Skip dead particles
    if (particle.life <= 0.0) return;
    
    // Transform to clip space
    float4 clipPos = culling.viewProjectionMatrix * float4(particle.position, 1.0);
    
    // Frustum test
    if (clipPos.x < -clipPos.w || clipPos.x > clipPos.w ||
        clipPos.y < -clipPos.w || clipPos.y > clipPos.w ||
        clipPos.z < -clipPos.w || clipPos.z > clipPos.w) {
        return;
    }
    
    // Distance culling
    float distance = length(particle.position - culling.cameraPosition);
    if (distance > culling.farPlane) return;
    
    // Particle is visible - add to visible list
    uint index = atomic_fetch_add_explicit(visibleCount, 1, memory_order_relaxed);
    visibleIndices[index] = id;
}

/// Particle sorting kernel for depth ordering
kernel void sortParticles(
    device uint* visibleIndices [[buffer(0)]],
    device float* depths [[buffer(1)]],
    constant CullingUniforms& culling [[buffer(2)]],
    uint id [[thread_position_in_grid]],
    uint threadsPerThreadgroup [[threads_per_threadgroup]]
) {
    // TODO: Implement GPU-based particle sorting
    // For now, this is a placeholder for bitonic sort or radix sort
}

// MARK: - Vertex Shaders

/// Vertex shader for particle rendering
vertex VertexOut particleVertex(
    const device Particle& particle [[buffer(0)]],
    constant CullingUniforms& culling [[buffer(1)]],
    uint id [[vertex_id]]
) {
    VertexOut out;
    
    // Skip dead particles
    if (particle.life <= 0.0) {
        out.position = float4(-1000.0, -1000.0, -1000.0, 1.0);
        out.pointSize = 0.0;
        return out;
    }
    
    // Transform particle position
    out.position = culling.viewProjectionMatrix * float4(particle.position, 1.0);
    out.color = particle.color;
    out.life = particle.life;
    out.size = particle.size;
    
    // Calculate point size based on distance and life
    float distance = length(particle.position - culling.cameraPosition);
    out.pointSize = particle.size * 1000.0 / distance * particle.life;
    
    return out;
}

// MARK: - Fragment Shaders

/// Fragment shader for particle rendering
fragment float4 particleFragment(
    VertexOut in [[stage_in]],
    texture2d<float> particleTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)],
    constant SimulationUniforms& uniforms [[buffer(0)]]
) {
    // Sample particle texture
    float2 uv = in.pointSize > 0.0 ? gl_PointCoord : float2(0.5);
    float4 texColor = particleTexture.sample(textureSampler, uv);
    
    // Create soft particle shape
    float dist = length(uv - float2(0.5));
    float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
    
    // Apply life-based fading
    alpha *= in.life * in.life;
    
    // Add subtle color variation
    float3 colorVariation = float3(
        sin(uniforms.time * 2.0 + in.position.x) * 0.1,
        sin(uniforms.time * 2.3 + in.position.y) * 0.1,
        sin(uniforms.time * 2.7 + in.position.z) * 0.1
    );
    
    float3 finalColor = in.color * (1.0 + colorVariation);
    
    return float4(finalColor, alpha * texColor.a);
}
