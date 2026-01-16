# Data Flow Visualization

## Overview

Data flow visualization represents the movement of information through network connections, showing how data packets travel between servers, the volume of traffic, and the patterns of communication. This research explores techniques for creating dynamic, informative data flow representations that enhance understanding of network behavior.

## Data Flow Models

### Packet Flow Simulation

```javascript
class PacketFlowSimulator {
  constructor() {
    this.packets = new Map();
    this.flows = new Map();
    this.simulationSpeed = 1.0;
  }
  
  createFlow(sourceId, targetId, properties) {
    const flow = {
      id: `flow-${sourceId}-${targetId}-${Date.now()}`,
      source: sourceId,
      target: targetId,
      packetRate: properties.packetRate || 10, // packets per second
      packetSize: properties.packetSize || 1500, // bytes
      protocol: properties.protocol || 'TCP',
      priority: properties.priority || 0,
      color: properties.color || 0x00ffff,
      active: true
    };
    
    this.flows.set(flow.id, flow);
    return flow.id;
  }
  
  generatePacket(flowId, timestamp) {
    const flow = this.flows.get(flowId);
    if (!flow || !flow.active) return null;
    
    const sourceNode = networkGraph.nodes.get(flow.source);
    const targetNode = networkGraph.nodes.get(flow.target);
    
    if (!sourceNode || !targetNode) return null;
    
    const packet = {
      id: `packet-${flowId}-${timestamp}`,
      flowId: flowId,
      position: { ...sourceNode.position },
      startTime: timestamp,
      progress: 0,
      size: flow.packetSize,
      color: flow.color,
      speed: this.calculatePacketSpeed(flow)
    };
    
    this.packets.set(packet.id, packet);
    return packet;
  }
  
  calculatePacketSpeed(flow) {
    // Simulate network latency and bandwidth
    const baseLatency = 50; // ms
    const distance = this.calculateDistance(flow.source, flow.target);
    const distanceLatency = distance * 0.01; // 10ms per 1000km
    
    const totalLatency = baseLatency + distanceLatency;
    return 1 / (totalLatency / 1000); // progress per second
  }
  
  calculateDistance(sourceId, targetId) {
    const source = networkGraph.nodes.get(sourceId);
    const target = networkGraph.nodes.get(targetId);
    
    if (!source || !target) return 0;
    
    return haversineDistance(
      source.position.lat,
      source.position.lon,
      target.position.lat,
      target.position.lon
    );
  }
  
  update(deltaTime) {
    const currentTime = Date.now();
    
    // Generate new packets based on flow rates
    for (const [flowId, flow] of this.flows) {
      if (!flow.active) continue;
      
      const packetsToGenerate = Math.floor(flow.packetRate * deltaTime);
      
      for (let i = 0; i < packetsToGenerate; i++) {
        this.generatePacket(flowId, currentTime + i * (1000 / flow.packetRate));
      }
    }
    
    // Update existing packets
    for (const [packetId, packet] of this.packets) {
      packet.progress += packet.speed * deltaTime;
      
      if (packet.progress >= 1.0) {
        this.packets.delete(packetId);
      } else {
        this.updatePacketPosition(packet);
      }
    }
  }
  
  updatePacketPosition(packet) {
    const flow = this.flows.get(packet.flowId);
    const sourceNode = networkGraph.nodes.get(flow.source);
    const targetNode = networkGraph.nodes.get(flow.target);
    
    // Interpolate position along great circle path
    const startPos = latLonToCartesian(
      sourceNode.position.lat,
      sourceNode.position.lon,
      1.01 // Slightly above surface
    );
    
    const endPos = latLonToCartesian(
      targetNode.position.lat,
      targetNode.position.lon,
      1.01
    );
    
    // Use spherical interpolation for great circle movement
    packet.position = this.interpolateGreatCircle(
      startPos,
      endPos,
      packet.progress
    );
  }
  
  interpolateGreatCircle(start, end, t) {
    // Spherical linear interpolation (slerp)
    const startNorm = start.clone().normalize();
    const endNorm = end.clone().normalize();
    
    const dot = startNorm.dot(endNorm);
    const clampedDot = Math.max(-1, Math.min(1, dot));
    
    const theta = Math.acos(clampedDot);
    
    if (Math.abs(theta) < 0.001) {
      return start.clone();
    }
    
    const sinTheta = Math.sin(theta);
    const factor1 = Math.sin((1 - t) * theta) / sinTheta;
    const factor2 = Math.sin(t * theta) / sinTheta;
    
    return startNorm.clone().multiplyScalar(factor1)
                    .add(endNorm.clone().multiplyScalar(factor2))
                    .multiplyScalar(start.length());
  }
}
```

### Traffic Volume Visualization

```javascript
class TrafficVolumeVisualizer {
  constructor() {
    this.volumeData = new Map();
    this.maxVolume = 0;
    this.decayRate = 0.95; // Exponential decay per second
  }
  
  recordTraffic(edgeId, volume) {
    if (!this.volumeData.has(edgeId)) {
      this.volumeData.set(edgeId, {
        current: 0,
        smoothed: 0,
        lastUpdate: Date.now()
      });
    }
    
    const data = this.volumeData.get(edgeId);
    data.current += volume;
    this.maxVolume = Math.max(this.maxVolume, data.current);
  }
  
  update(deltaTime) {
    for (const [edgeId, data] of this.volumeData) {
      // Apply exponential decay
      data.current *= Math.pow(this.decayRate, deltaTime);
      data.smoothed = data.smoothed * 0.9 + data.current * 0.1;
      
      // Update edge visualization
      this.updateEdgeVisualization(edgeId, data.smoothed);
    }
  }
  
  updateEdgeVisualization(edgeId, volume) {
    const edge = networkGraph.edges.get(edgeId);
    if (!edge) return;
    
    const normalizedVolume = volume / this.maxVolume;
    
    // Update edge width
    edge.visualWidth = 0.01 + normalizedVolume * 0.05;
    
    // Update edge color
    const hue = (1 - normalizedVolume) * 0.3; // Red to green
    edge.visualColor = new THREE.Color().setHSL(hue, 1, 0.5);
    
    // Update edge opacity
    edge.visualOpacity = 0.3 + normalizedVolume * 0.7;
  }
  
  getVolumeHistory(edgeId, timeWindow = 60000) {
    // Return volume history for trend analysis
    const history = [];
    const now = Date.now();
    
    // This would typically come from a time-series database
    // For demo purposes, we'll generate mock data
    for (let i = 0; i < 60; i++) {
      const time = now - (60 - i) * 1000;
      const volume = Math.random() * this.maxVolume * 0.5;
      history.push({ time, volume });
    }
    
    return history;
  }
}
```

## Flow Animation Techniques

### Particle-Based Flow

```javascript
class ParticleFlowRenderer {
  constructor(scene, maxParticles = 10000) {
    this.scene = scene;
    this.maxParticles = maxParticles;
    this.particlePool = new ParticlePool(maxParticles);
    this.activeFlows = new Map();
  }
  
  createFlowVisualization(flowId, properties) {
    const flow = packetFlowSimulator.flows.get(flowId);
    if (!flow) return;
    
    const visualization = {
      flowId: flowId,
      particleRate: properties.particleRate || 10,
      particleLifetime: properties.lifetime || 3000,
      particleSize: properties.size || 0.02,
      color: properties.color || 0x00ffff,
      lastEmission: 0
    };
    
    this.activeFlows.set(flowId, visualization);
  }
  
  update(deltaTime) {
    const now = Date.now();
    
    for (const [flowId, visualization] of this.activeFlows) {
      // Calculate particles to emit
      const timeSinceLastEmission = now - visualization.lastEmission;
      const emissionInterval = 1000 / visualization.particleRate;
      
      if (timeSinceLastEmission >= emissionInterval) {
        const particlesToEmit = Math.floor(timeSinceLastEmission / emissionInterval);
        
        for (let i = 0; i < particlesToEmit; i++) {
          this.emitParticle(flowId, visualization);
        }
        
        visualization.lastEmission = now;
      }
    }
    
    // Update active particles
    this.updateParticles(deltaTime);
  }
  
  emitParticle(flowId, visualization) {
    const particle = this.particlePool.get();
    if (!particle) return;
    
    const flow = packetFlowSimulator.flows.get(flowId);
    const sourceNode = networkGraph.nodes.get(flow.source);
    const targetNode = networkGraph.nodes.get(flow.target);
    
    // Initialize particle
    particle.position = latLonToCartesian(
      sourceNode.position.lat,
      sourceNode.position.lon,
      1.01
    );
    
    particle.velocity = new THREE.Vector3();
    particle.life = visualization.particleLifetime;
    particle.maxLife = visualization.particleLifetime;
    particle.size = visualization.particleSize;
    particle.color = visualization.color;
    particle.flowId = flowId;
    
    // Calculate initial velocity toward target
    const targetPos = latLonToCartesian(
      targetNode.position.lat,
      targetNode.position.lon,
      1.01
    );
    
    const direction = targetPos.clone().sub(particle.position).normalize();
    particle.velocity.copy(direction.multiplyScalar(0.1));
    
    this.scene.add(particle.mesh);
  }
  
  updateParticles(deltaTime) {
    for (const particle of this.particlePool.activeParticles) {
      // Update position
      particle.position.add(particle.velocity.clone().multiplyScalar(deltaTime));
      
      // Update life
      particle.life -= deltaTime * 1000;
      
      // Update visual properties
      const lifeRatio = particle.life / particle.maxLife;
      particle.mesh.material.opacity = lifeRatio;
      particle.mesh.scale.setScalar(lifeRatio);
      
      // Check if particle should be removed
      if (particle.life <= 0) {
        this.particlePool.release(particle);
      }
    }
  }
}

class ParticlePool {
  constructor(maxSize) {
    this.maxSize = maxSize;
    this.pool = [];
    this.activeParticles = new Set();
    
    // Pre-allocate particles
    for (let i = 0; i < maxSize; i++) {
      const geometry = new THREE.SphereGeometry(0.01, 8, 8);
      const material = new THREE.MeshBasicMaterial({
        color: 0x00ffff,
        transparent: true,
        opacity: 1.0
      });
      
      const mesh = new THREE.Mesh(geometry, material);
      
      this.pool.push({
        mesh: mesh,
        position: new THREE.Vector3(),
        velocity: new THREE.Vector3(),
        life: 0,
        maxLife: 0,
        size: 0.01,
        color: 0x00ffff,
        active: false
      });
    }
  }
  
  get() {
    if (this.pool.length === 0) return null;
    
    const particle = this.pool.pop();
    particle.active = true;
    this.activeParticles.add(particle);
    
    return particle;
  }
  
  release(particle) {
    particle.active = false;
    particle.mesh.material.opacity = 0;
    this.activeParticles.delete(particle);
    this.pool.push(particle);
  }
}
```

### Shader-Based Flow

```javascript
class ShaderFlowRenderer {
  constructor() {
    this.flowMaterials = new Map();
  }
  
  createFlowMaterial(flowId, properties) {
    const material = new THREE.ShaderMaterial({
      uniforms: {
        uTime: { value: 0 },
        uSpeed: { value: properties.speed || 1 },
        uColor: { value: new THREE.Color(properties.color || 0x00ffff) },
        uIntensity: { value: properties.intensity || 1 },
        uFlowDirection: { value: properties.direction || 1 }
      },
      vertexShader: `
        varying vec2 vUv;
        varying vec3 vPosition;
        
        void main() {
          vUv = uv;
          vPosition = position;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: `
        uniform float uTime;
        uniform float uSpeed;
        uniform vec3 uColor;
        uniform float uIntensity;
        uniform float uFlowDirection;
        varying vec2 vUv;
        varying vec3 vPosition;
        
        void main() {
          // Create flowing pattern
          float flowCoord = vUv.x * uFlowDirection;
          float wave = sin((flowCoord - uTime * uSpeed) * 10.0) * 0.5 + 0.5;
          
          // Create packet-like shapes
          float packet = smoothstep(0.0, 0.1, wave) * smoothstep(1.0, 0.9, wave);
          
          vec3 color = uColor * (0.3 + packet * 0.7) * uIntensity;
          
          gl_FragColor = vec4(color, 1.0);
        }
      `,
      transparent: true,
      blending: THREE.AdditiveBlending
    });
    
    this.flowMaterials.set(flowId, material);
    return material;
  }
  
  update(deltaTime) {
    for (const [flowId, material] of this.flowMaterials) {
      material.uniforms.uTime.value += deltaTime;
    }
  }
}
```

## Bandwidth Visualization

### Real-Time Bandwidth Monitoring

```javascript
class BandwidthMonitor {
  constructor() {
    this.bandwidthData = new Map();
    this.maxBandwidth = 1000; // Mbps
    this.updateInterval = 1000; // 1 second
    this.lastUpdate = Date.now();
  }
  
  recordBandwidth(edgeId, bytesTransferred) {
    const now = Date.now();
    const timeDiff = (now - this.lastUpdate) / 1000; // seconds
    
    if (!this.bandwidthData.has(edgeId)) {
      this.bandwidthData.set(edgeId, {
        current: 0,
        history: [],
        max: 0
      });
    }
    
    const data = this.bandwidthData.get(edgeId);
    const bandwidth = (bytesTransferred * 8) / (timeDiff * 1000000); // Mbps
    
    data.current = bandwidth;
    data.max = Math.max(data.max, bandwidth);
    
    // Add to history (keep last 60 seconds)
    data.history.push({ time: now, bandwidth });
    if (data.history.length > 60) {
      data.history.shift();
    }
    
    this.lastUpdate = now;
  }
  
  getBandwidthTrend(edgeId, timeWindow = 60000) {
    const data = this.bandwidthData.get(edgeId);
    if (!data) return [];
    
    const now = Date.now();
    return data.history.filter(
      point => now - point.time <= timeWindow
    );
  }
  
  visualizeBandwidth(edgeId) {
    const data = this.bandwidthData.get(edgeId);
    if (!data) return;
    
    const normalizedBandwidth = data.current / this.maxBandwidth;
    
    // Update edge visualization
    const edge = networkGraph.edges.get(edgeId);
    if (edge) {
      edge.visualWidth = 0.01 + normalizedBandwidth * 0.1;
      edge.visualOpacity = 0.3 + normalizedBandwidth * 0.7;
      
      // Color based on utilization
      const hue = (1 - normalizedBandwidth) * 0.3; // Green to red
      edge.visualColor = new THREE.Color().setHSL(hue, 1, 0.5);
    }
  }
}
```

### Aggregated Flow Visualization

```javascript
class AggregatedFlowVisualizer {
  constructor() {
    this.flowAggregates = new Map();
    this.aggregationWindow = 5000; // 5 seconds
  }
  
  aggregateFlows() {
    // Group flows by source/target regions
    const regionFlows = new Map();
    
    for (const [flowId, flow] of packetFlowSimulator.flows) {
      const sourceRegion = this.getRegionForNode(flow.source);
      const targetRegion = this.getRegionForNode(flow.target);
      
      if (sourceRegion !== targetRegion) {
        const key = `${sourceRegion}-${targetRegion}`;
        
        if (!regionFlows.has(key)) {
          regionFlows.set(key, {
            sourceRegion,
            targetRegion,
            totalVolume: 0,
            flowCount: 0,
            lastUpdate: Date.now()
          });
        }
        
        const aggregate = regionFlows.get(key);
        aggregate.totalVolume += flow.packetRate * flow.packetSize;
        aggregate.flowCount += 1;
        aggregate.lastUpdate = Date.now();
      }
    }
    
    this.flowAggregates = regionFlows;
  }
  
  getRegionForNode(nodeId) {
    const node = networkGraph.nodes.get(nodeId);
    if (!node) return 'unknown';
    
    // Simple region mapping based on coordinates
    const lat = node.position.lat;
    const lon = node.position.lon;
    
    if (lat > 0 && lon < 0) return 'North America';
    if (lat > 0 && lon > 0) return 'Europe';
    if (lat < 0 && lon > 0) return 'Africa/Asia';
    if (lat < 0 && lon < 0) return 'South America';
    
    return 'Other';
  }
  
  visualizeAggregatedFlows() {
    for (const [key, aggregate] of this.flowAggregates) {
      const normalizedVolume = Math.log10(aggregate.totalVolume + 1) / 10;
      
      // Create or update visual representation
      this.updateAggregateVisualization(aggregate, normalizedVolume);
    }
  }
  
  updateAggregateVisualization(aggregate, intensity) {
    // This would create curved lines between regions
    // with thickness and opacity based on traffic volume
    console.log(`Flow from ${aggregate.sourceRegion} to ${aggregate.targetRegion}: ${intensity}`);
  }
}
```

## Conclusion

Data flow visualization is a critical component of network monitoring systems, providing real-time insights into traffic patterns, bandwidth utilization, and network health. The techniques presented here enable the creation of comprehensive data flow visualizations that are both informative and performant.

Key implementation strategies include:
- **Packet Simulation**: Realistic modeling of network traffic patterns
- **Multiple Visualization Techniques**: Particle systems, shader-based effects, and bandwidth monitoring
- **Performance Optimization**: Efficient particle pooling and LOD systems
- **Real-Time Updates**: Dynamic adaptation to changing network conditions
- **Aggregated Views**: High-level overviews of regional traffic patterns

These approaches provide network operators with the tools needed to understand, monitor, and optimize their global network infrastructure effectively.