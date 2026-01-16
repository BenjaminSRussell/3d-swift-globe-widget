# Sphere to Plane Morphing Mathematics

## Overview

The core visual requirement for the Cyber-Physical Globe is the seamless transition between 3D spherical and 2D planar representations. This transformation must maintain topological continuity, allowing users to track geographic features as they morph between projections.

## Mathematical Foundation

### Coordinate System Definitions

**Spherical Coordinates (3D Mode)**:
- Radius: R (constant for all points)
- Latitude: φ ∈ [-π/2, π/2]
- Longitude: θ ∈ [-π, π]

**Planar Coordinates (2D Mode)**:
- x ∈ [-πR, πR] (longitude mapped to width)
- y ∈ [-πR/2, πR/2] (latitude mapped to height)
- z = 0 (flat plane)

### Transformation Equations

#### Spherical to Cartesian Conversion
```
x = R × cos(φ) × cos(θ)
y = R × sin(φ)
z = R × cos(φ) × sin(θ)
```

#### UV Coordinate Mapping
For a plane geometry with UV coordinates (u,v) ∈ [0,1]:
```
θ = (u - 0.5) × 2π    // longitude from -π to π
φ = (v - 0.5) × π     // latitude from -π/2 to π/2
```

#### Planar Projection
```
x = θ × R              // direct longitude mapping
y = φ × R              // direct latitude mapping
z = 0                  // flat plane
```

### Vertex Shader Implementation

#### Core Morphing Logic
```glsl
uniform float uMix;    // 0.0 = sphere, 1.0 = plane
uniform float uRadius; // sphere radius

attribute vec2 uv;     // UV coordinates from plane geometry

varying vec3 vPosition;
varying vec3 vNormal;
varying vec2 vUv;

void main() {
  vUv = uv;
  
  // Convert UV to spherical coordinates
  float theta = (uv.x - 0.5) * 2.0 * 3.14159;  // -π to π
  float phi = (uv.y - 0.5) * 3.14159;          // -π/2 to π/2
  
  // Calculate spherical position
  vec3 sphericalPos = vec3(
    uRadius * cos(phi) * cos(theta),
    uRadius * sin(phi),
    uRadius * cos(phi) * sin(theta)
  );
  
  // Calculate planar position
  vec3 planarPos = vec3(
    theta * uRadius,
    phi * uRadius,
    0.0
  );
  
  // Interpolate between positions
  vPosition = mix(sphericalPos, planarPos, uMix);
  
  // Calculate normals
  vec3 sphericalNormal = normalize(sphericalPos);
  vec3 planarNormal = vec3(0.0, 0.0, 1.0);
  
  vNormal = mix(sphericalNormal, planarNormal, uMix);
  
  gl_Position = projectionMatrix * modelViewMatrix * vec4(vPosition, 1.0);
}
```

## Projection Distortion Analysis

### Equirectangular Projection Properties

**Advantages**:
- Simple mapping from spherical to planar coordinates
- Preserves straight meridians and parallels
- Compatible with standard geographic imagery
- Minimal computational overhead

**Disadvantages**:
- Severe area distortion at poles
- Shape distortion increases with latitude
- Not conformal (angles not preserved)

### Distortion Quantification

#### Area Distortion Function
```javascript
function calculateAreaDistortion(latitude) {
  // Equirectangular projection area distortion
  // True area element: cos(φ)
  // Projected area element: 1
  // Distortion: 1/cos(φ)
  
  const phi = latitude * Math.PI / 180;
  return 1 / Math.cos(phi);
}

// Example: 60° latitude has 2x area distortion
const distortionAt60Deg = calculateAreaDistortion(60); // 2.0
```

#### Angular Distortion
```javascript
function calculateAngularDistortion(latitude) {
  // Maximum angular distortion in degrees
  const phi = latitude * Math.PI / 180;
  return Math.acos(Math.cos(phi) / Math.sqrt(1 + Math.cos(phi) * Math.cos(phi))) * 180 / Math.PI;
}
```

## Alternative Projections

### Mercator Projection

**Mathematical Formulation**:
```
x = R × θ
y = R × ln(tan(π/4 + φ/2))
```

**Inverse Transformation**:
```
θ = x / R
φ = 2 × arctan(e^(y/R)) - π/2
```

**Properties**:
- Conformal (preserves angles)
- Straight rhumb lines
- Infinite at poles (cannot show 90° latitude)

### Robinson Projection

**Mathematical Formulation**:
```
x = R × θ × 0.8487
y = R × (0.8470 × φ - 0.0655 × φ³ + 0.0015 × φ⁵)
```

**Properties**:
- Compromise projection
- Pleasant aesthetic appearance
- Used by National Geographic Society

## Morphing Animation Curves

### Easing Functions

#### Smoothstep Interpolation
```glsl
float smoothstep(float edge0, float edge1, float x) {
  float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// Usage in morphing animation
float easedMix = smoothstep(0.0, 1.0, uMix);
```

#### Cubic Ease In/Out
```glsl
float cubicEaseInOut(float t) {
  return t < 0.5 
    ? 4.0 * t * t * t 
    : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
}
```

### Animation Timing

#### Recommended Duration
- **Morph Duration**: 800-1200ms
- **Easing**: Cubic ease in/out
- **Stagger Delay**: 50ms between multiple morphs

## Seam Handling

### UV Seam Problem

At longitude ±π (the international date line), the UV coordinates jump from 1.0 to 0.0, creating a visible seam in the 3D sphere mode.

#### Solution: Duplicate Vertices
```javascript
function createSeamlessSphereGeometry(widthSegments, heightSegments) {
  const geometry = new THREE.PlaneGeometry(2, 1, widthSegments, heightSegments);
  
  // Duplicate vertices at the seam
  const position = geometry.attributes.position;
  const uv = geometry.attributes.uv;
  
  for (let y = 0; y <= heightSegments; y++) {
    // Find vertices at u = 0 and u = 1
    const index0 = y * (widthSegments + 1);
    const index1 = y * (widthSegments + 1) + widthSegments;
    
    // Ensure they have the same world position but different UVs
    position.setXYZ(index1, position.getX(index0), position.getY(index0), position.getZ(index0));
  }
  
  geometry.computeVertexNormals();
  return geometry;
}
```

### Normal Vector Interpolation

#### Smooth Normal Transition
```glsl
vec3 calculateMixedNormal(vec3 sphericalNormal, vec3 planarNormal, float mixFactor) {
  // Use slerp (spherical linear interpolation) for normals
  float dotProduct = dot(sphericalNormal, planarNormal);
  float theta = acos(clamp(dotProduct, -1.0, 1.0));
  
  if (theta < 0.001) {
    return sphericalNormal;
  }
  
  float sinTheta = sin(theta);
  float factor = sin(mixFactor * theta) / sinTheta;
  
  return normalize(
    sphericalNormal * cos(mixFactor * theta) + 
    (planarNormal - sphericalNormal * dotProduct) * factor
  );
}
```

## Lighting Considerations

### Dynamic Lighting Model

#### Rim Lighting (Fresnel Effect)
```glsl
float fresnelFactor = 1.0 - abs(dot(viewDirection, surfaceNormal));
float rimIntensity = pow(fresnelFactor, 2.0);
vec3 rimColor = vec3(0.0, 1.0, 1.0) * rimIntensity;
```

#### Ambient and Directional Light
```glsl
vec3 ambientLight = vec3(0.2, 0.2, 0.3);
vec3 directionalLight = vec3(0.8, 0.8, 0.7) * max(0.0, dot(surfaceNormal, lightDirection));

vec3 finalColor = baseColor * (ambientLight + directionalLight) + rimColor;
```

## Performance Optimization

### Level of Detail (LOD)

#### Adaptive Geometry Resolution
```javascript
function getOptimalSegments(distance, targetPixelSize = 2) {
  // Calculate required segments based on distance
  const circumference = 2 * Math.PI * 6371; // Earth's circumference in km
  const angularSize = 2 * Math.atan(circumference / (2 * distance));
  const pixels = angularSize / targetPixelSize;
  
  // Round to nearest power of 2 for optimal GPU performance
  return Math.pow(2, Math.ceil(Math.log2(pixels / 10)));
}
```

### Frustum Culling

#### Efficient Culling for Morphing Geometry
```javascript
function updateMorphingCulling(mesh, mixFactor) {
  const geometry = mesh.geometry;
  const position = geometry.attributes.position;
  
  let minX = Infinity, maxX = -Infinity;
  let minY = Infinity, maxY = -Infinity;
  let minZ = Infinity, maxZ = -Infinity;
  
  for (let i = 0; i < position.count; i++) {
    const vertex = new THREE.Vector3().fromBufferAttribute(position, i);
    
    // Transform based on current mix factor
    const spherical = sphericalFromUV(vertex.x, vertex.y);
    const planar = planarFromUV(vertex.x, vertex.y);
    const transformed = spherical.clone().lerp(planar, mixFactor);
    
    minX = Math.min(minX, transformed.x);
    maxX = Math.max(maxX, transformed.x);
    minY = Math.min(minY, transformed.y);
    maxY = Math.max(maxY, transformed.y);
    minZ = Math.min(minZ, transformed.z);
    maxZ = Math.max(maxZ, transformed.z);
  }
  
  // Update bounding box for frustum culling
  mesh.geometry.boundingBox.set(
    new THREE.Vector3(minX, minY, minZ),
    new THREE.Vector3(maxX, maxY, maxZ)
  );
}
```

## Implementation Example

### Complete Morphing Globe Component
```jsx
function MorphingGlobe({ mixFactor, radius = 1 }) {
  const geometry = useMemo(() => {
    const geo = new THREE.PlaneGeometry(2, 1, 360, 180);
    return geo;
  }, []);
  
  const material = useMemo(() => {
    return new THREE.ShaderMaterial({
      vertexShader: `
        uniform float uMix;
        uniform float uRadius;
        varying vec2 vUv;
        varying vec3 vNormal;
        
        void main() {
          vUv = uv;
          
          float theta = (uv.x - 0.5) * 2.0 * 3.14159;
          float phi = (uv.y - 0.5) * 3.14159;
          
          vec3 sphericalPos = vec3(
            uRadius * cos(phi) * cos(theta),
            uRadius * sin(phi),
            uRadius * cos(phi) * sin(theta)
          );
          
          vec3 planarPos = vec3(
            theta * uRadius,
            phi * uRadius,
            0.0
          );
          
          vPosition = mix(sphericalPos, planarPos, uMix);
          vNormal = mix(normalize(sphericalPos), vec3(0.0, 0.0, 1.0), uMix);
          
          gl_Position = projectionMatrix * modelViewMatrix * vec4(vPosition, 1.0);
        }
      `,
      fragmentShader: `
        varying vec2 vUv;
        varying vec3 vNormal;
        
        void main() {
          // Grid pattern
          vec2 grid = abs(fract(vUv * 10.0) - 0.5);
          float line = smoothstep(0.48, 0.52, max(grid.x, grid.y));
          
          gl_FragColor = vec4(0.0, 1.0, 1.0, line);
        }
      `,
      uniforms: {
        uMix: { value: mixFactor },
        uRadius: { value: radius }
      }
    });
  }, [mixFactor, radius]);
  
  return (
    <mesh geometry={geometry} material={material} />
  );
}
```

## Conclusion

The sphere-to-plane morphing transformation requires careful mathematical treatment to maintain visual continuity and topological consistency. The equirectangular projection provides the simplest implementation with acceptable distortion characteristics for most visualization use cases.

Key implementation considerations:
- Vertex shader interpolation for smooth morphing
- Proper normal vector handling for consistent lighting
- Seam management for spherical geometry
- Performance optimization through LOD and culling
- Animation easing for natural transitions

The mathematical foundation presented here enables the creation of visually stunning and technically robust geospatial visualization systems that meet both aesthetic and performance requirements.