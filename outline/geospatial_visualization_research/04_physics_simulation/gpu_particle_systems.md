# GPU Particle Systems

## Introduction

GPU-based particle systems enable the simulation of massive numbers of particles with complex behaviors, essential for creating the "delicate bursting" effects required for connection failure visualization. This research explores the technical implementation of high-performance particle systems using WebGL and Three.js.

## GPU Particle Architecture

### Core Design Principles

**CPU vs GPU Trade-offs**:
- **CPU Particles**: ~5,000 max, complex logic, easy debugging
- **GPU Particles**: 100,000+ max, simple behaviors, parallel execution

#### GPU Particle Structure
```javascript
class GPUParticleSystem {
  constructor(maxParticles = 100000) {
    this.maxParticles = maxParticles;
    this.activeParticles = 0;
    
    // Particle data stored in textures/buffers
    this.positionBuffer = new Float32Array(maxParticles * 3);
    this.velocityBuffer = new Float32Array(maxParticles * 3);
    this.lifeBuffer = new Float32Array(maxParticles);
    this.colorBuffer = new Float32Array(maxParticles * 3);
    this.sizeBuffer = new Float32Array(maxParticles);
    
    // WebGL buffers
    this.setupBuffers();
    this.setupShaders();
  }
  
  setupBuffers() {
    // Position buffer
    this.positionAttribute = new THREE.InstancedBufferAttribute(
      this.positionBuffer, 3, false, 1
    );
    
    // Velocity buffer (for shader access)
    this.velocityTexture = this.createDataTexture(
      this.velocityBuffer, 
      Math.ceil(Math.sqrt(maxParticles)), 
      Math.ceil(Math.sqrt(maxParticles))
    );
    
    // Life buffer
    this.lifeAttribute = new THREE.InstancedBufferAttribute(
      this.lifeBuffer, 1, false, 1
    );
  }
  
  createDataTexture(data, width, height) {
    const texture = new THREE.DataTexture(
      data, 
      width, 
      height, 
      THREE.RGBAFormat, 
      THREE.FloatType
    );
    texture.needsUpdate = true;
    return texture;
  }
}
```

### Instanced Rendering Setup

```javascript
class InstancedParticleRenderer {
  constructor(scene, maxInstances = 100000) {
    this.scene = scene;
    this.maxInstances = maxInstances;
    this.activeInstances = 0;
    
    this.setupInstancedMesh();
    this.setupSimulation();
  }
  
  setupInstancedMesh() {
    // Base geometry for each particle
    const particleGeometry = new THREE.SphereGeometry(0.01, 8, 8);
    
    // Instanced mesh
    this.instancedMesh = new THREE.InstancedMesh(
      particleGeometry,
      this.createParticleMaterial(),
      this.maxInstances
    );
    
    // Instance attributes
    this.instanceColor = new THREE.InstancedBufferAttribute(
      new Float32Array(this.maxInstances * 3), 3, false
    );
    this.instanceLife = new THREE.InstancedBufferAttribute(
      new Float32Array(this.maxInstances), 1, false
    );
    this.instanceSize = new THREE.InstancedBufferAttribute(
      new Float32Array(this.maxInstances), 1, false
    );
    
    this.instancedMesh.instanceColor = this.instanceColor;
    this.instancedMesh.setAttribute('instanceLife', this.instanceLife);
    this.instancedMesh.setAttribute('instanceSize', this.instanceSize);
    
    this.scene.add(this.instancedMesh);
  }
  
  createParticleMaterial() {
    return new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uPixelRatio: { value: Math.min(window.devicePixelRatio, 2) },
        uTexture: { value: this.createParticleTexture() }
      },
      vertexShader: `
        attribute float instanceLife;
        attribute float instanceSize;
        attribute vec3 instanceColor;
        
        uniform float uTime;
        uniform float uPixelRatio;
        
        varying float vLife;
        varying vec3 vColor;
        varying vec2 vUv;
        
        void main() {
          vLife = instanceLife;
          vColor = instanceColor;
          vUv = uv;
          
          vec4 worldPosition = modelMatrix * vec4(position, 1.0);
          worldPosition.xyz += instanceMatrix[3].xyz;
          
          // Scale by life and size
          float scale = instanceSize * instanceLife;
          worldPosition.xyz += position * scale;
          
          vec4 mvPosition = viewMatrix * worldPosition;
          
          // Screen-space scaling
          gl_PointSize = scale * 300.0 / -mvPosition.z * uPixelRatio;
          
          gl_Position = projectionMatrix * mvPosition;
        }
      `,
      fragmentShader: `
        uniform sampler2D uTexture;
        uniform float uTime;
        
        varying float vLife;
        varying vec3 vColor;
        varying vec2 vUv;
        
        void main() {
          vec4 texColor = texture2D(uTexture, gl_PointCoord);
          
          // Fade out with life
          float alpha = texColor.a * vLife * vLife; // Square for faster fade
          
          // Color with some variation
          vec3 color = vColor * (0.8 + 0.2 * sin(uTime * 2.0));
          
          gl_FragColor = vec4(color, alpha);
        }
      `,
      transparent: true,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    });
  }
  
  createParticleTexture() {
    const canvas = document.createElement('canvas');
    canvas.width = 64;
    canvas.height = 64;
    const ctx = canvas.getContext('2d');
    
    // Create gradient particle texture
    const gradient = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    gradient.addColorStop(0, 'rgba(255,255,255,1)');
    gradient.addColorStop(0.5, 'rgba(255,255,255,0.5)');
    gradient.addColorStop(1, 'rgba(255,255,255,0)');
    
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 64, 64);
    
    const texture = new THREE.CanvasTexture(canvas);
    return texture;
  }
}
```

## Particle Physics Simulation

### GPGPU Particle Simulation

```javascript
class GPGPUParticleSimulation {
  constructor(renderer, maxParticles = 100000) {
    this.renderer = renderer;
    this.maxParticles = maxParticles;
    this.size = Math.ceil(Math.sqrt(maxParticles));
    
    this.setupSimulation();
  }
  
  setupSimulation() {
    // Create render targets for position and velocity
    this.positionRT1 = this.createRenderTarget();
    this.positionRT2 = this.createRenderTarget();
    this.velocityRT1 = this.createRenderTarget();
    this.velocityRT2 = this.createRenderTarget();
    
    // Simulation material
    this.simulationMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uPositions: { value: this.positionRT1.texture },
        uVelocities: { value: this.velocityRT1.texture },
        uDeltaTime: { value: 0.016 },
        uGravity: { value: new THREE.Vector3(0, -9.8, 0) },
        uDamping: { value: 0.99 },
        uTime: { value: 0 }
      },
      vertexShader: `
        varying vec2 vUv;
        
        void main() {
          vUv = uv;
          gl_Position = vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform sampler2D uPositions;
        uniform sampler2D uVelocities;
        uniform float uDeltaTime;
        uniform vec3 uGravity;
        uniform float uDamping;
        uniform float uTime;
        
        varying vec2 vUv;
        
        void main() {
          vec3 position = texture2D(uPositions, vUv).xyz;
          vec3 velocity = texture2D(uVelocities, vUv).xyz;
          float life = texture2D(uPositions, vUv).w;
          
          // Apply forces
          velocity += uGravity * uDeltaTime;
          
          // Apply damping
          velocity *= uDamping;
          
          // Update position
          position += velocity * uDeltaTime;
          
          // Decrease life
          life -= uDeltaTime * 0.5;
          
          gl_FragColor = vec4(position, life);
        }
      `
    });
    
    // Velocity update material
    this.velocityMaterial = new THREE.ShaderMaterial({
      uniforms: {
        uVelocities: { value: this.velocityRT1.texture },
        uDeltaTime: { value: 0.016 },
        uTime: { value: 0 }
      },
      vertexShader: `
        varying vec2 vUv;
        
        void main() {
          vUv = uv;
          gl_Position = vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform sampler2D uVelocities;
        uniform float uDeltaTime;
        uniform float uTime;
        
        varying vec2 vUv;
        
        void main() {
          vec3 velocity = texture2D(uVelocities, vUv).xyz;
          float life = texture2D(uVelocities, vUv).w;
          
          // Add some turbulence
          vec3 turbulence = vec3(
            sin(uTime + vUv.x * 10.0) * 0.1,
            cos(uTime + vUv.y * 10.0) * 0.1,
            sin(uTime * 1.5 + vUv.x * 5.0) * 0.1
          );
          
          velocity += turbulence * uDeltaTime;
          
          gl_FragColor = vec4(velocity, life);
        }
      `
    });
    
    // Fullscreen quad for simulation
    this.simulationQuad = new THREE.Mesh(
      new THREE.PlaneGeometry(2, 2),
      this.simulationMaterial
    );
    
    this.velocityQuad = new THREE.Mesh(
      new THREE.PlaneGeometry(2, 2),
      this.velocityMaterial
    );
    
    // Camera and scene for off-screen rendering
    this.simulationCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    this.simulationScene = new THREE.Scene();
  }
  
  createRenderTarget() {
    return new THREE.WebGLRenderTarget(this.size, this.size, {
      wrapS: THREE.ClampToEdgeWrapping,
      wrapT: THREE.ClampToEdgeWrapping,
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      format: THREE.RGBAFormat,
      type: THREE.FloatType,
      stencilBuffer: false
    });
  }
  
  update(deltaTime) {
    // Update uniforms
    this.simulationMaterial.uniforms.uDeltaTime.value = deltaTime;
    this.simulationMaterial.uniforms.uTime.value += deltaTime;
    
    this.velocityMaterial.uniforms.uDeltaTime.value = deltaTime;
    this.velocityMaterial.uniforms.uTime.value += deltaTime;
    
    // Swap render targets
    this.simulationMaterial.uniforms.uPositions.value = this.positionRT1.texture;
    this.simulationMaterial.uniforms.uVelocities.value = this.velocityRT1.texture;
    
    // Render position update
    this.simulationScene.add(this.simulationQuad);
    this.renderer.setRenderTarget(this.positionRT2);
    this.renderer.render(this.simulationScene, this.simulationCamera);
    
    // Render velocity update
    this.velocityMaterial.uniforms.uVelocities.value = this.velocityRT1.texture;
    this.simulationScene.children[0].material = this.velocityMaterial;
    this.renderer.setRenderTarget(this.velocityRT2);
    this.renderer.render(this.simulationScene, this.simulationCamera);
    
    // Swap buffers
    [this.positionRT1, this.positionRT2] = [this.positionRT2, this.positionRT1];
    [this.velocityRT1, this.velocityRT2] = [this.velocityRT2, this.velocityRT1];
    
    this.renderer.setRenderTarget(null);
  }
}
```

## Curl Noise for Fluid Motion

### Mathematical Foundation

Curl noise provides divergence-free vector fields that create natural, fluid-like motion:

```glsl
// 3D Noise function
vec3 noise3D(vec3 p) {
  return vec3(
    sin(p.x * 2.0 + p.y * 1.5 + p.z * 1.0),
    sin(p.y * 2.0 + p.z * 1.5 + p.x * 1.0),
    sin(p.z * 2.0 + p.x * 1.5 + p.y * 1.0)
  );
}

// Curl of noise field
vec3 curlNoise(vec3 p) {
  const float eps = 0.01;
  
  vec3 dx = vec3(eps, 0.0, 0.0);
  vec3 dy = vec3(0.0, eps, 0.0);
  vec3 dz = vec3(0.0, 0.0, eps);
  
  float n1 = noise3D(p + dx).y - noise3D(p - dx).y;
  float n2 = noise3D(p + dy).x - noise3D(p - dy).x;
  float n3 = noise3D(p + dz).y - noise3D(p - dz).y;
  float n4 = noise3D(p + dx).z - noise3D(p - dx).z;
  float n5 = noise3D(p + dz).x - noise3D(p - dz).x;
  float n6 = noise3D(p + dy).z - noise3D(p - dy).z;
  
  return vec3(n6 - n3, n4 - n5, n1 - n2) / (2.0 * eps);
}
```

### Implementation in Particle System

```javascript
class CurlNoiseParticleSystem {
  constructor(scene, maxParticles = 50000) {
    this.scene = scene;
    this.maxParticles = maxParticles;
    this.particles = [];
    this.noise = new SimplexNoise();
    
    this.setupParticles();
  }
  
  setupParticles() {
    // Create instanced mesh for particles
    const geometry = new THREE.SphereGeometry(0.005, 6, 6);
    const material = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uNoiseScale: { value: 0.1 },
        uNoiseSpeed: { value: 0.5 },
        uDamping: { value: 0.98 }
      },
      vertexShader: `
        attribute float instanceLife;
        attribute float instanceSize;
        attribute vec3 instanceColor;
        attribute vec3 instanceVelocity;
        
        uniform float uTime;
        uniform float uNoiseScale;
        uniform float uNoiseSpeed;
        uniform float uDamping;
        
        varying float vLife;
        varying vec3 vColor;
        varying float vSize;
        
        // 3D noise function
        vec3 noise3D(vec3 p) {
          return vec3(
            sin(p.x * 2.0 + p.y * 1.5 + p.z * 1.0 + uTime * uNoiseSpeed),
            sin(p.y * 2.0 + p.z * 1.5 + p.x * 1.0 + uTime * uNoiseSpeed * 1.1),
            sin(p.z * 2.0 + p.x * 1.5 + p.y * 1.0 + uTime * uNoiseSpeed * 0.9)
          );
        }
        
        // Curl noise calculation
        vec3 curlNoise(vec3 p) {
          const float eps = 0.01;
          
          vec3 dx = vec3(eps, 0.0, 0.0);
          vec3 dy = vec3(0.0, eps, 0.0);
          vec3 dz = vec3(0.0, 0.0, eps);
          
          float n1 = noise3D(p + dx).y - noise3D(p - dx).y;
          float n2 = noise3D(p + dy).x - noise3D(p - dy).x;
          float n3 = noise3D(p + dz).y - noise3D(p - dz).y;
          float n4 = noise3D(p + dx).z - noise3D(p - dx).z;
          float n5 = noise3D(p + dz).x - noise3D(p - dz).x;
          float n6 = noise3D(p + dy).z - noise3D(p - dy).z;
          
          return vec3(n6 - n3, n4 - n5, n1 - n2) / (2.0 * eps);
        }
        
        void main() {
          vLife = instanceLife;
          vColor = instanceColor;
          vSize = instanceSize * instanceLife;
          
          vec3 position = instanceMatrix[3].xyz;
          vec3 velocity = instanceVelocity;
          
          // Apply curl noise
          vec3 noiseForce = curlNoise(position * uNoiseScale) * 0.1;
          velocity += noiseForce;
          
          // Apply damping
          velocity *= uDamping;
          
          // Update position
          position += velocity * 0.016; // Assuming 60 FPS
          
          // Transform to world space
          vec4 worldPosition = modelMatrix * vec4(position, 1.0);
          worldPosition.xyz += position * vSize;
          
          vec4 mvPosition = viewMatrix * worldPosition;
          gl_Position = projectionMatrix * mvPosition;
        }
      `,
      fragmentShader: `
        varying float vLife;
        varying vec3 vColor;
        varying float vSize;
        
        void main() {
          // Create soft particle shape
          float dist = length(gl_PointCoord - vec2(0.5));
          float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
          
          // Fade with life
          alpha *= vLife * vLife;
          
          vec3 color = vColor * (0.8 + 0.2 * vLife);
          
          gl_FragColor = vec4(color, alpha);
        }
      `,
      transparent: true,
      blending: THREE.AdditiveBlending,
      depthWrite: false
    });
    
    this.instancedMesh = new THREE.InstancedMesh(
      geometry,
      material,
      this.maxParticles
    );
    
    this.scene.add(this.instancedMesh);
    this.setupInstanceAttributes();
  }
  
  setupInstanceAttributes() {
    // Life attribute
    this.instanceLife = new THREE.InstancedBufferAttribute(
      new Float32Array(this.maxParticles), 1, false
    );
    
    // Size attribute
    this.instanceSize = new THREE.InstancedBufferAttribute(
      new Float32Array(this.maxParticles), 1, false
    );
    
    // Color attribute
    this.instanceColor = new THREE.InstancedBufferAttribute(
      new Float32Array(this.maxParticles * 3), 3, false
    );
    
    // Velocity attribute (for CPU update)
    this.velocities = new Float32Array(this.maxParticles * 3);
    
    this.instancedMesh.setAttribute('instanceLife', this.instanceLife);
    this.instancedMesh.setAttribute('instanceSize', this.instanceSize);
    this.instancedMesh.setAttribute('instanceColor', this.instanceColor);
  }
  
  emitBurst(position, count = 100, properties = {}) {
    const baseColor = properties.color || new THREE.Color(0xff0055);
    const baseSize = properties.size || 0.02;
    const velocityScale = properties.velocityScale || 1;
    
    for (let i = 0; i < count && this.activeInstances < this.maxParticles; i++) {
      const index = this.activeInstances++;
      
      // Random direction
      const direction = new THREE.Vector3(
        (Math.random() - 0.5) * 2,
        Math.random(), // Bias upward
        (Math.random() - 0.5) * 2
      ).normalize();
      
      // Random velocity
      const velocity = direction.multiplyScalar(
        (Math.random() * 0.5 + 0.5) * velocityScale
      );
      
      // Set instance data
      this.instancedMesh.setMatrixAt(index, new THREE.Matrix4().setPosition(position));
      
      this.instanceLife.setX(index, 1.0);
      this.instanceSize.setX(index, baseSize * (Math.random() * 0.5 + 0.5));
      
      const colorVariation = Math.random() * 0.2 + 0.8;
      this.instanceColor.setXYZ(
        index,
        baseColor.r * colorVariation,
        baseColor.g * colorVariation,
        baseColor.b * colorVariation
      );
      
      // Store velocity
      this.velocities[index * 3] = velocity.x;
      this.velocities[index * 3 + 1] = velocity.y;
      this.velocities[index * 3 + 2] = velocity.z;
    }
    
    this.instancedMesh.instanceMatrix.needsUpdate = true;
    this.instanceLife.needsUpdate = true;
    this.instanceSize.needsUpdate = true;
    this.instanceColor.needsUpdate = true;
  }
  
  update(deltaTime) {
    // Update material uniforms
    this.instancedMesh.material.uniforms.uTime.value += deltaTime;
    
    // Update particle life
    for (let i = 0; i < this.activeInstances; i++) {
      const currentLife = this.instanceLife.getX(i);
      const newLife = Math.max(0, currentLife - deltaTime * 0.5);
      
      this.instanceLife.setX(i, newLife);
      
      // Remove dead particles
      if (newLife <= 0) {
        this.removeParticle(i);
        i--;
      }
    }
    
    if (this.activeInstances > 0) {
      this.instanceLife.needsUpdate = true;
    }
  }
  
  removeParticle(index) {
    // Swap with last active particle
    const lastIndex = this.activeInstances - 1;
    
    if (index < lastIndex) {
      // Copy last particle to current index
      const lastMatrix = new THREE.Matrix4();
      this.instancedMesh.getMatrixAt(lastIndex, lastMatrix);
      this.instancedMesh.setMatrixAt(index, lastMatrix);
      
      this.instanceLife.setX(index, this.instanceLife.getX(lastIndex));
      this.instanceSize.setX(index, this.instanceSize.getX(lastIndex));
      
      const lastColor = new THREE.Color();
      lastColor.fromBufferAttribute(this.instanceColor, lastIndex);
      this.instanceColor.setXYZ(index, lastColor.r, lastColor.g, lastColor.b);
    }
    
    this.activeInstances--;
    
    // Mark buffers for update
    this.instancedMesh.instanceMatrix.needsUpdate = true;
    this.instanceLife.needsUpdate = true;
    this.instanceSize.needsUpdate = true;
    this.instanceColor.needsUpdate = true;
  }
}
```

## Performance Optimization

### Level of Detail (LOD)

```javascript
class ParticleLOD {
  constructor() {
    this.lodLevels = [
      { distance: 0, particleCount: 100000, quality: 'high' },
      { distance: 100, particleCount: 50000, quality: 'medium' },
      { distance: 500, particleCount: 10000, quality: 'low' },
      { distance: 1000, particleCount: 1000, quality: 'minimal' }
    ];
  }
  
  getLODLevel(cameraDistance) {
    for (let i = this.lodLevels.length - 1; i >= 0; i--) {
      if (cameraDistance >= this.lodLevels[i].distance) {
        return this.lodLevels[i];
      }
    }
    return this.lodLevels[0];
  }
  
  updateParticleCount(system, cameraPosition, burstPosition) {
    const distance = cameraPosition.distanceTo(burstPosition);
    const lod = this.getLODLevel(distance);
    
    system.maxParticles = lod.particleCount;
    return lod;
  }
}
```

### Frustum Culling

```javascript
class ParticleCulling {
  constructor(camera) {
    this.camera = camera;
    this.frustum = new THREE.Frustum();
    this.cameraMatrix = new THREE.Matrix4();
  }
  
  updateFrustum() {
    this.cameraMatrix.multiplyMatrices(
      this.camera.projectionMatrix,
      this.camera.matrixWorldInverse
    );
    this.frustum.setFromProjectionMatrix(this.cameraMatrix);
  }
  
  isParticleVisible(position, radius = 0.1) {
    const sphere = new THREE.Sphere(position, radius);
    return this.frustum.intersectsSphere(sphere);
  }
  
  cullParticles(particles) {
    this.updateFrustum();
    
    const visibleParticles = [];
    for (const particle of particles) {
      if (this.isParticleVisible(particle.position, particle.size)) {
        visibleParticles.push(particle);
      }
    }
    
    return visibleParticles;
  }
}
```

## Burst Effect Implementation

### Connection Failure Burst

```javascript
class ConnectionFailureBurst {
  constructor(particleSystem) {
    this.particleSystem = particleSystem;
    this.burstPatterns = new Map();
  }
  
  createBurst(connectionId, position, properties = {}) {
    const burst = {
      id: `burst-${connectionId}-${Date.now()}`,
      position: position.clone(),
      startTime: Date.now(),
      duration: properties.duration || 2000,
      particleCount: properties.particleCount || 100,
      pattern: properties.pattern || 'explosive',
      color: properties.color || new THREE.Color(0xff0055),
      intensity: properties.intensity || 1
    };
    
    this.burstPatterns.set(burst.id, burst);
    this.executeBurstPattern(burst);
    
    return burst.id;
  }
  
  executeBurstPattern(burst) {
    switch (burst.pattern) {
      case 'explosive':
        this.createExplosiveBurst(burst);
        break;
      case 'fountain':
        this.createFountainBurst(burst);
        break;
      case 'spiral':
        this.createSpiralBurst(burst);
        break;
      case 'shockwave':
        this.createShockwaveBurst(burst);
        break;
      default:
        this.createExplosiveBurst(burst);
    }
  }
  
  createExplosiveBurst(burst) {
    const directions = this.generateUniformDirections(burst.particleCount);
    
    for (let i = 0; i < burst.particleCount; i++) {
      const velocity = directions[i].multiplyScalar(
        Math.random() * 2 + 1 * burst.intensity
      );
      
      this.particleSystem.emitParticle({
        position: burst.position,
        velocity: velocity,
        life: Math.random() * 0.5 + 0.5,
        size: Math.random() * 0.02 + 0.01,
        color: burst.color,
        mass: Math.random() * 0.5 + 0.5
      });
    }
  }
  
  createFountainBurst(burst) {
    const baseDirection = new THREE.Vector3(0, 1, 0);
    const spread = 0.5; // radians
    
    for (let i = 0; i < burst.particleCount; i++) {
      const direction = baseDirection.clone();
      
      // Add random spread
      direction.applyAxisAngle(
        new THREE.Vector3(Math.random() - 0.5, 0, Math.random() - 0.5).normalize(),
        (Math.random() - 0.5) * spread
      );
      
      const velocity = direction.multiplyScalar(
        Math.random() * 3 + 2 * burst.intensity
      );
      
      this.particleSystem.emitParticle({
        position: burst.position,
        velocity: velocity,
        life: Math.random() * 0.8 + 0.4,
        size: Math.random() * 0.03 + 0.02,
        color: burst.color,
        mass: Math.random() * 0.3 + 0.2
      });
    }
  }
  
  createSpiralBurst(burst) {
    const spiralTurns = 3;
    const spiralRadius = 0.1;
    
    for (let i = 0; i < burst.particleCount; i++) {
      const t = i / burst.particleCount;
      const angle = t * spiralTurns * Math.PI * 2;
      const radius = t * spiralRadius;
      
      const direction = new THREE.Vector3(
        Math.cos(angle) * radius,
        t,
        Math.sin(angle) * radius
      ).normalize();
      
      const velocity = direction.multiplyScalar(
        (1 - t) * 4 * burst.intensity
      );
      
      this.particleSystem.emitParticle({
        position: burst.position,
        velocity: velocity,
        life: Math.random() * 0.6 + 0.3,
        size: Math.random() * 0.015 + 0.005,
        color: burst.color,
        mass: Math.random() * 0.4 + 0.1
      });
    }
  }
  
  createShockwaveBurst(burst) {
    const rings = 5;
    const particlesPerRing = burst.particleCount / rings;
    
    for (let ring = 0; ring < rings; ring++) {
      const ringDelay = ring * 100; // ms
      const ringRadius = (ring + 1) * 0.05;
      
      setTimeout(() => {
        for (let i = 0; i < particlesPerRing; i++) {
          const angle = (i / particlesPerRing) * Math.PI * 2;
          
          const direction = new THREE.Vector3(
            Math.cos(angle),
            0,
            Math.sin(angle)
          );
          
          const velocity = direction.multiplyScalar(
            (rings - ring) * 0.5 * burst.intensity
          );
          
          this.particleSystem.emitParticle({
            position: burst.position,
            velocity: velocity,
            life: Math.random() * 0.4 + 0.2,
            size: Math.random() * 0.01 + 0.005,
            color: burst.color,
            mass: Math.random() * 0.2 + 0.1
          });
        }
      }, ringDelay);
    }
  }
  
  generateUniformDirections(count) {
    const directions = [];
    
    // Fibonacci sphere distribution for uniform directions
    const phi = Math.PI * (3 - Math.sqrt(5)); // Golden angle
    
    for (let i = 0; i < count; i++) {
      const y = 1 - (i / (count - 1)) * 2; // -1 to 1
      const radius = Math.sqrt(1 - y * y);
      const theta = phi * i;
      
      directions.push(new THREE.Vector3(
        Math.cos(theta) * radius,
        y,
        Math.sin(theta) * radius
      ));
    }
    
    return directions;
  }
  
  update(deltaTime) {
    const now = Date.now();
    
    // Clean up old bursts
    for (const [burstId, burst] of this.burstPatterns) {
      if (now - burst.startTime > burst.duration) {
        this.burstPatterns.delete(burstId);
      }
    }
  }
}
```

## Conclusion

GPU particle systems provide the computational power needed to create stunning visual effects for network visualization. The key to successful implementation lies in:

1. **Parallel Processing**: Leveraging GPU capabilities for massive particle counts
2. **Efficient Memory Management**: Using textures and buffers for particle data
3. **Advanced Physics**: Implementing curl noise and fluid dynamics
4. **Performance Optimization**: Applying LOD, culling, and instanced rendering
5. **Visual Quality**: Creating diverse burst patterns and smooth animations

The techniques presented here enable the creation of "delicate" particle effects that enhance the user experience while maintaining the 60 FPS performance required for professional network monitoring systems.