# Bézier Curve Mathematics for Arc Visualization

## Introduction

Bézier curves provide the mathematical foundation for creating smooth, aesthetically pleasing arcs that visualize network connections on the Cyber-Physical Globe. This research explores the mathematical principles and implementation strategies for generating dynamic arcs that respond to the 3D-to-2D morphing transformation.

## Bézier Curve Fundamentals

### Mathematical Definition

A Bézier curve of degree n is defined by:

$$B(t) = \sum_{i=0}^{n} \binom{n}{i} (1-t)^{n-i} t^i P_i$$

where:
- $t \in [0, 1]$ is the parameter
- $P_i$ are the control points
- $\binom{n}{i}$ are the binomial coefficients

### Quadratic Bézier Curve (Degree 2)

For three control points $P_0$, $P_1$, $P_2$:

$$B(t) = (1-t)^2 P_0 + 2(1-t)t P_1 + t^2 P_2$$

**Expanded Form**:
```
x(t) = (1-t)²x₀ + 2(1-t)tx₁ + t²x₂
y(t) = (1-t)²y₀ + 2(1-t)ty₁ + t²y₂
z(t) = (1-t)²z₀ + 2(1-t)tz₁ + t²z₂
```

### Cubic Bézier Curve (Degree 3)

For four control points $P_0$, $P_1$, $P_2$, $P_3$:

$$B(t) = (1-t)^3 P_0 + 3(1-t)^2 t P_1 + 3(1-t)t^2 P_2 + t^3 P_3$$

**JavaScript Implementation**:
```javascript
function cubicBezier(t, p0, p1, p2, p3) {
  const u = 1 - t;
  const uu = u * u;
  const uuu = uu * u;
  const tt = t * t;
  const ttt = tt * t;
  
  const p = uuu * p0; // (1-t)³P₀
  p += 3 * uu * t * p1; // 3(1-t)²tP₁
  p += 3 * u * tt * p2; // 3(1-t)t²P₂
  p += ttt * p3; // t³P₃
  
  return p;
}
```

## Arc Generation for Network Connections

### Great Circle Arcs

#### Control Point Calculation for Spherical Arcs
```javascript
function createSphericalArc(startLat, startLon, endLat, endLon, radius = 1, arcHeight = 0.2) {
  // Convert to Cartesian coordinates
  const start = latLonToCartesian(startLat, startLon, radius);
  const end = latLonToCartesian(endLat, endLon, radius);
  
  // Calculate midpoint on sphere
  const mid = new THREE.Vector3().addVectors(start, end).normalize().multiplyScalar(radius);
  
  // Calculate control point (loft the arc)
  const control = mid.clone().multiplyScalar(1 + arcHeight);
  
  return { start, control, end };
}

function latLonToCartesian(lat, lon, radius) {
  const phi = lat * Math.PI / 180;
  const theta = lon * Math.PI / 180;
  
  return new THREE.Vector3(
    radius * Math.cos(phi) * Math.cos(theta),
    radius * Math.sin(phi),
    radius * Math.cos(phi) * Math.sin(theta)
  );
}
```

#### Adaptive Arc Height Based on Distance
```javascript
function calculateOptimalArcHeight(startLat, startLon, endLat, endLon) {
  // Calculate great circle distance
  const distance = haversineDistance(startLat, startLon, endLat, endLon);
  
  // Normalize to 0-1 range (assuming max distance is half Earth's circumference)
  const maxDistance = 20000; // ~20,000 km
  const normalizedDistance = Math.min(distance / maxDistance, 1);
  
  // Use non-linear scaling for better visual distinction
  const arcHeight = 0.1 + 0.4 * Math.pow(normalizedDistance, 1.5);
  
  return arcHeight;
}
```

### Bézier Curve Tessellation

#### Generating Arc Vertices
```javascript
function generateArcVertices(start, control, end, numSegments = 64) {
  const vertices = [];
  
  for (let i = 0; i <= numSegments; i++) {
    const t = i / numSegments;
    const vertex = quadraticBezier(t, start, control, end);
    vertices.push(vertex);
  }
  
  return vertices;
}

function quadraticBezier(t, p0, p1, p2) {
  const u = 1 - t;
  return p0.clone().multiplyScalar(u * u)
           .add(p1.clone().multiplyScalar(2 * u * t))
           .add(p2.clone().multiplyScalar(t * t));
}
```

### Dynamic Morphing for 3D/2D Transition

#### Adaptive Control Points
```javascript
function createMorphingArc(startLat, startLon, endLat, endLon, mixFactor) {
  // Get 3D positions
  const start3D = latLonToCartesian(startLat, startLon, 1);
  const end3D = latLonToCartesian(endLat, endLon, 1);
  
  // Get 2D positions
  const start2D = latLonToPlanar(startLat, startLon);
  const end2D = latLonToPlanar(endLat, endLon);
  
  // Interpolate positions based on mix factor
  const start = start3D.clone().lerp(start2D, mixFactor);
  const end = end3D.clone().lerp(end2D, mixFactor);
  
  // Calculate control point
  let control;
  if (mixFactor < 0.5) {
    // 3D-style control point (radial)
    const mid3D = new THREE.Vector3().addVectors(start3D, end3D).normalize();
    const arcHeight = calculateOptimalArcHeight(startLat, startLon, endLat, endLon);
    control = mid3D.multiplyScalar(1 + arcHeight);
    control.lerp(new THREE.Vector3().addVectors(start2D, end2D).multiplyScalar(0.5), mixFactor * 2);
  } else {
    // 2D-style control point (vertical jump)
    const mid2D = new THREE.Vector3().addVectors(start2D, end2D).multiplyScalar(0.5);
    control = mid2D.clone().add(new THREE.Vector3(0, 0, 0.2));
    control.lerp(mid2D, (mixFactor - 0.5) * 2);
  }
  
  return { start, control, end };
}

function latLonToPlanar(lat, lon) {
  // Simple equirectangular projection
  const x = (lon / 180) * Math.PI;
  const y = (lat / 90) * Math.PI / 2;
  return new THREE.Vector3(x, y, 0);
}
```

## Arc Rendering Techniques

### Mesh-Based Arcs

#### Creating Volumetric Arc Geometry
```javascript
function createArcMesh(start, control, end, width = 0.02, segments = 64) {
  const curve = new THREE.QuadraticBezierCurve3(start, control, end);
  
  // Create tube geometry along the curve
  const geometry = new THREE.TubeGeometry(curve, segments, width, 8, false);
  
  // Create material with custom shader for animation
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uSpeed: { value: 1 },
      uColor: { value: new THREE.Color(0x00ffff) }
    },
    vertexShader: `
      varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform float uTime;
      uniform float uSpeed;
      uniform vec3 uColor;
      varying vec2 vUv;
      
      void main() {
        // Animate pulse along the arc
        float pulse = sin((vUv.x - uTime * uSpeed) * 10.0) * 0.5 + 0.5;
        vec3 color = uColor * (0.5 + pulse * 0.5);
        
        gl_FragColor = vec4(color, 1.0);
      }
    `
  });
  
  return new THREE.Mesh(geometry, material);
}
```

### Instanced Arc Rendering

#### Efficient Multiple Arcs
```javascript
function createInstancedArcs(connections, mixFactor) {
  const instances = connections.length;
  
  // Create base geometry (simple tube)
  const baseGeometry = new THREE.CylinderGeometry(0.01, 0.01, 1, 8);
  
  // Create instanced mesh
  const instancedMesh = new THREE.InstancedMesh(
    baseGeometry,
    arcMaterial,
    instances
  );
  
  const dummy = new THREE.Object3D();
  
  connections.forEach((connection, index) => {
    const { start, control, end } = createMorphingArc(
      connection.startLat,
      connection.startLon,
      connection.endLat,
      connection.endLon,
      mixFactor
    );
    
    // Calculate transformation matrix
    const midpoint = new THREE.Vector3().addVectors(start, end).multiplyScalar(0.5);
    const direction = new THREE.Vector3().subVectors(end, start);
    const length = direction.length();
    
    dummy.position.copy(midpoint);
    dummy.scale.set(1, length, 1);
    dummy.lookAt(end);
    dummy.updateMatrix();
    
    instancedMesh.setMatrixAt(index, dummy.matrix);
    
    // Store curve for animation
    const curve = new THREE.QuadraticBezierCurve3(start, control, end);
    instancedMesh.userData.curves[index] = curve;
  });
  
  instancedMesh.instanceMatrix.needsUpdate = true;
  
  return instancedMesh;
}
```

## Advanced Arc Features

### Gradient Coloring

#### Distance-Based Gradient
```javascript
function createGradientArcMaterial(start, end) {
  const distance = start.distanceTo(end);
  const maxDistance = 2; // Normalized
  
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uDistance: { value: distance / maxDistance },
      uColor1: { value: new THREE.Color(0x00ffff) },
      uColor2: { value: new THREE.Color(0xff00ff) }
    },
    vertexShader: `
      varying float vDistance;
      void main() {
        vDistance = position.x; // Use x coordinate as distance along arc
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }
    `,
    fragmentShader: `
      uniform float uDistance;
      uniform vec3 uColor1;
      uniform vec3 uColor2;
      varying float vDistance;
      
      void main() {
        float t = smoothstep(0.0, 1.0, vDistance);
        vec3 color = mix(uColor1, uColor2, t * uDistance);
        
        gl_FragColor = vec4(color, 1.0);
      }
    `
  });
  
  return material;
}
```

### Arc Animation Systems

#### Ping Animation
```javascript
class ArcAnimationSystem {
  constructor() {
    this.arcs = new Map();
    this.animationId = null;
  }
  
  addArc(id, arcMesh, speed = 1) {
    this.arcs.set(id, {
      mesh: arcMesh,
      speed: speed,
      time: Math.random() * 100 // Random offset
    });
  }
  
  startAnimation() {
    const animate = () => {
      const time = Date.now() * 0.001;
      
      this.arcs.forEach((arc, id) => {
        const elapsed = time * arc.speed + arc.time;
        arc.mesh.material.uniforms.uTime.value = elapsed;
      });
      
      this.animationId = requestAnimationFrame(animate);
    };
    
    animate();
  }
  
  stopAnimation() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }
}
```

## Performance Optimization

### Arc LOD (Level of Detail)

```javascript
function getOptimalArcSegments(distance, viewportSize) {
  // Base segments for close-up view
  const baseSegments = 64;
  
  // Reduce segments based on distance
  const distanceFactor = Math.max(0.1, Math.min(1, 1000 / distance));
  
  // Reduce segments based on screen size
  const screenFactor = Math.max(0.5, Math.min(1, viewportSize / 1000));
  
  return Math.floor(baseSegments * distanceFactor * screenFactor);
}
```

### Culling Strategies

```javascript
function isArcInFrustum(start, end, frustum) {
  // Create bounding sphere for the arc
  const center = new THREE.Vector3().addVectors(start, end).multiplyScalar(0.5);
  const radius = start.distanceTo(end) / 2;
  
  const sphere = new THREE.Sphere(center, radius);
  return frustum.intersectsSphere(sphere);
}
```

## Conclusion

Bézier curves provide the mathematical foundation for creating visually appealing and performant network connection arcs. The key to successful implementation lies in:

1. **Adaptive Control Points**: Adjust arc height based on connection distance
2. **Dynamic Morphing**: Smooth transition between 3D spherical and 2D planar representations
3. **Efficient Rendering**: Use instanced rendering and LOD for performance
4. **Visual Enhancement**: Implement gradient coloring and animation systems
5. **Mathematical Precision**: Ensure accurate great circle calculations for realistic connections

The combination of these techniques enables the creation of beautiful, informative network visualizations that enhance the user's understanding of global connectivity patterns.