# High-Frequency State Management

## Overview

High-frequency state management handles data that updates at 60 FPS, such as particle positions, camera movements, and animation states. This research explores techniques for managing rapidly changing data without triggering expensive React re-renders.

## State Classification

### Frequency-Based State Categories

```javascript
const STATE_FREQUENCIES = {
  REALTIME: 'realtime',    // 60 FPS - particle positions, camera
  ANIMATION: 'animation',  // 30-60 FPS - UI animations, transitions
  SIMULATION: 'simulation', // 10-30 FPS - network simulation updates
  UI: 'ui',                // 1-5 FPS - user interactions, selections
  DATA: 'data'             // 0.1-1 FPS - server lists, topology changes
};

class FrequencyBasedState {
  constructor() {
    this.states = new Map();
    this.updateLoops = new Map();
    this.frameCount = 0;
    
    this.initializeUpdateLoops();
  }
  
  initializeUpdateLoops() {
    // Realtime loop (60 FPS)
    this.updateLoops.set(STATE_FREQUENCIES.REALTIME, {
      frequency: 60,
      lastUpdate: 0,
      callbacks: new Set()
    });
    
    // Animation loop (30 FPS)
    this.updateLoops.set(STATE_FREQUENCIES.ANIMATION, {
      frequency: 30,
      lastUpdate: 0,
      callbacks: new Set()
    });
    
    // Simulation loop (20 FPS)
    this.updateLoops.set(STATE_FREQUENCIES.SIMULATION, {
      frequency: 20,
      lastUpdate: 0,
      callbacks: new Set()
    });
    
    // UI loop (5 FPS)
    this.updateLoops.set(STATE_FREQUENCIES.UI, {
      frequency: 5,
      lastUpdate: 0,
      callbacks: new Set()
    });
    
    // Data loop (1 FPS)
    this.updateLoops.set(STATE_FREQUENCIES.DATA, {
      frequency: 1,
      lastUpdate: 0,
      callbacks: new Set()
    });
  }
  
  subscribe(frequency, callback) {
    const loop = this.updateLoops.get(frequency);
    if (loop) {
      loop.callbacks.add(callback);
    }
  }
  
  unsubscribe(frequency, callback) {
    const loop = this.updateLoops.get(frequency);
    if (loop) {
      loop.callbacks.delete(callback);
    }
  }
  
  update(deltaTime) {
    this.frameCount++;
    const now = Date.now();
    
    for (const [frequency, loop] of this.updateLoops) {
      const interval = 1000 / loop.frequency;
      
      if (now - loop.lastUpdate >= interval) {
        loop.lastUpdate = now;
        
        for (const callback of loop.callbacks) {
          try {
            callback(deltaTime, this.frameCount);
          } catch (error) {
            console.error(`Error in ${frequency} callback:`, error);
          }
        }
      }
    }
  }
}
```

## Zustand Integration for High-Frequency Updates

### Store Architecture

```javascript
import { create } from 'zustand';
import { subscribeWithSelector } from 'zustand/middleware';

const useSimulationStore = create(
  subscribeWithSelector((set, get) => ({
    // High-frequency data (updated every frame)
    particles: {
      positions: new Float32Array(100000 * 3),
      velocities: new Float32Array(100000 * 3),
      life: new Float32Array(100000),
      count: 0
    },
    
    camera: {
      position: new THREE.Vector3(0, 0, 5),
      target: new THREE.Vector3(0, 0, 0),
      needsUpdate: false
    },
    
    animation: {
      time: 0,
      deltaTime: 0.016,
      frameCount: 0,
      isPlaying: true
    },
    
    // Methods for high-frequency updates (no re-renders)
    updateParticle: (index, position, velocity, life) => {
      const particles = get().particles;
      const i3 = index * 3;
      
      particles.positions[i3] = position.x;
      particles.positions[i3 + 1] = position.y;
      particles.positions[i3 + 2] = position.z;
      
      particles.velocities[i3] = velocity.x;
      particles.velocities[i3 + 1] = velocity.y;
      particles.velocities[i3 + 2] = velocity.z;
      
      particles.life[index] = life;
    },
    
    setParticleCount: (count) => {
      set((state) => ({
        particles: { ...state.particles, count }
      }));
    },
    
    updateCamera: (position, target) => {
      set((state) => ({
        camera: {
          position: position.clone(),
          target: target.clone(),
          needsUpdate: true
        }
      }));
    },
    
    updateAnimation: (time, deltaTime, frameCount) => {
      set((state) => ({
        animation: {
          ...state.animation,
          time,
          deltaTime,
          frameCount
        }
      }));
    },
    
    // Low-frequency data (triggers re-renders)
    selectedNodes: new Set(),
    hoveredNode: null,
    viewMode: '3D',
    showUI: true,
    
    // Methods for low-frequency updates
    setSelectedNodes: (nodes) => {
      set({ selectedNodes: new Set(nodes) });
    },
    
    setHoveredNode: (nodeId) => {
      set({ hoveredNode: nodeId });
    },
    
    setViewMode: (mode) => {
      set({ viewMode: mode });
    },
    
    toggleUI: () => {
      set((state) => ({ showUI: !state.showUI }));
    }
  }))
);

// Subscribe to changes without causing re-renders
const unsubscribeParticleUpdates = useSimulationStore.subscribe(
  (state) => state.particles,
  (particles) => {
    // This callback won't trigger re-renders
    // It's used for debugging or external systems
    console.log('Particles updated:', particles.count);
  },
  { fireImmediately: false }
);
```

## React Integration Patterns

### Separating High and Low Frequency State

```jsx
import React, { useRef, useEffect, useState } from 'react';
import { useFrame } from '@react-three/fiber';

function Scene() {
  const meshRef = useRef();
  
  // Low-frequency state (causes re-renders)
  const { selectedNodes, viewMode, showUI } = useSimulationStore();
  
  // High-frequency state (no re-renders)
  const particles = useRef(useSimulationStore.getState().particles);
  const camera = useRef(useSimulationStore.getState().camera);
  
  // Subscribe to high-frequency updates without re-renders
  useEffect(() => {
    const unsubscribeParticles = useSimulationStore.subscribe(
      (state) => state.particles,
      (newParticles) => {
        particles.current = newParticles;
      }
    );
    
    const unsubscribeCamera = useSimulationStore.subscribe(
      (state) => state.camera,
      (newCamera) => {
        camera.current = newCamera;
      }
    );
    
    return () => {
      unsubscribeParticles();
      unsubscribeCamera();
    };
  }, []);
  
  // Animation loop (runs every frame)
  useFrame((state, deltaTime) => {
    // Update high-frequency state directly
    const time = state.clock.getElapsedTime();
    const frameCount = Math.floor(time * 60);
    
    useSimulationStore.getState().updateAnimation(time, deltaTime, frameCount);
    
    // Update particle positions
    updateParticles(deltaTime);
    
    // Update camera if needed
    if (camera.current.needsUpdate) {
      state.camera.position.copy(camera.current.position);
      state.camera.lookAt(camera.current.target);
      camera.current.needsUpdate = false;
    }
  });
  
  function updateParticles(deltaTime) {
    const { particles, updateParticle } = useSimulationStore.getState();
    
    for (let i = 0; i < particles.count; i++) {
      const i3 = i * 3;
      
      // Get current state
      const position = new THREE.Vector3(
        particles.positions[i3],
        particles.positions[i3 + 1],
        particles.positions[i3 + 2]
      );
      
      const velocity = new THREE.Vector3(
        particles.velocities[i3],
        particles.velocities[i3 + 1],
        particles.velocities[i3 + 2]
      );
      
      let life = particles.life[i];
      
      // Update physics
      velocity.add(new THREE.Vector3(0, -9.8, 0).multiplyScalar(deltaTime));
      position.add(velocity.clone().multiplyScalar(deltaTime));
      life -= deltaTime * 0.5;
      
      // Update in store (no re-render)
      updateParticle(i, position, velocity, life);
    }
  }
  
  return (
    <group>
      {/* Low-frequency updates cause re-renders */}
      {showUI && <UI selectedNodes={selectedNodes} />}
      
      {/* High-frequency updates don't cause re-renders */}
      <ParticleSystem 
        particles={particles.current}
        viewMode={viewMode}
      />
    </group>
  );
}
```

## Performance Optimization

### Batched Updates

```javascript
class BatchedUpdater {
  constructor() {
    this.pendingUpdates = new Map();
    this.batchSize = 1000;
    this.updateInterval = null;
  }
  
  scheduleUpdate(type, id, updateFn) {
    if (!this.pendingUpdates.has(type)) {
      this.pendingUpdates.set(type, new Map());
    }
    
    this.pendingUpdates.get(type).set(id, updateFn);
  }
  
  startBatching() {
    if (this.updateInterval) return;
    
    this.updateInterval = setInterval(() => {
      this.processBatch();
    }, 16); // Process every frame
  }
  
  stopBatching() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
  }
  
  processBatch() {
    const startTime = performance.now();
    let processed = 0;
    
    for (const [type, updates] of this.pendingUpdates) {
      const updateEntries = Array.from(updates.entries());
      
      for (let i = 0; i < Math.min(updateEntries.length, this.batchSize); i++) {
        const [id, updateFn] = updateEntries[i];
        
        try {
          updateFn();
          updates.delete(id);
          processed++;
        } catch (error) {
          console.error(`Error processing update for ${id}:`, error);
          updates.delete(id);
        }
        
        // Check time budget
        if (performance.now() - startTime > 8) { // 8ms budget
          break;
        }
      }
      
      if (updates.size === 0) {
        this.pendingUpdates.delete(type);
      }
    }
    
    console.log(`Processed ${processed} updates in ${performance.now() - startTime}ms`);
  }
}

const batchedUpdater = new BatchedUpdater();
```

### Memory-Efficient State Updates

```javascript
class EfficientStateUpdater {
  constructor() {
    this.updateBuffer = new Float32Array(10000); // Buffer for batched updates
    this.updateCount = 0;
  }
  
  queueUpdate(index, values) {
    const baseIndex = this.updateCount * 4; // index + x + y + z
    
    this.updateBuffer[baseIndex] = index;
    this.updateBuffer[baseIndex + 1] = values.x;
    this.updateBuffer[baseIndex + 2] = values.y;
    this.updateBuffer[baseIndex + 3] = values.z;
    
    this.updateCount++;
    
    if (this.updateCount >= 2500) { // 10000 / 4
      this.flushUpdates();
    }
  }
  
  flushUpdates() {
    if (this.updateCount === 0) return;
    
    const { particles, updateParticle } = useSimulationStore.getState();
    
    for (let i = 0; i < this.updateCount; i++) {
      const baseIndex = i * 4;
      const particleIndex = this.updateBuffer[baseIndex];
      
      const position = new THREE.Vector3(
        this.updateBuffer[baseIndex + 1],
        this.updateBuffer[baseIndex + 2],
        this.updateBuffer[baseIndex + 3]
      );
      
      // Update particle using existing data
      const i3 = particleIndex * 3;
      const velocity = new THREE.Vector3(
        particles.velocities[i3],
        particles.velocities[i3 + 1],
        particles.velocities[i3 + 2]
      );
      
      updateParticle(particleIndex, position, velocity, particles.life[particleIndex]);
    }
    
    this.updateCount = 0;
  }
}
```

## Web Workers Integration

### Offloading Computation

```javascript
// worker.js
self.addEventListener('message', (event) => {
  const { type, data } = event.data;
  
  switch (type) {
    case 'UPDATE_PARTICLES':
      const updatedParticles = updateParticlesInWorker(data);
      self.postMessage({
        type: 'PARTICLES_UPDATED',
        data: updatedParticles
      });
      break;
      
    case 'CALCULATE_PHYSICS':
      const physicsResult = calculatePhysics(data);
      self.postMessage({
        type: 'PHYSICS_CALCULATED',
        data: physicsResult
      });
      break;
  }
});

function updateParticlesInWorker(particleData) {
  const { positions, velocities, life, deltaTime } = particleData;
  
  for (let i = 0; i < positions.length; i += 3) {
    // Apply gravity
    velocities[i + 1] -= 9.8 * deltaTime;
    
    // Update positions
    positions[i] += velocities[i] * deltaTime;
    positions[i + 1] += velocities[i + 1] * deltaTime;
    positions[i + 2] += velocities[i + 2] * deltaTime;
    
    // Update life
    life[i / 3] -= deltaTime * 0.5;
  }
  
  return { positions, velocities, life };
}

// main.js
class WorkerStateManager {
  constructor() {
    this.worker = new Worker('worker.js');
    this.pendingUpdates = new Map();
    this.workerReady = false;
    
    this.worker.addEventListener('message', (event) => {
      this.handleWorkerMessage(event.data);
    });
  }
  
  handleWorkerMessage(message) {
    const { type, data } = message;
    
    switch (type) {
      case 'PARTICLES_UPDATED':
        this.applyParticleUpdate(data);
        break;
        
      case 'PHYSICS_CALCULATED':
        this.applyPhysicsUpdate(data);
        break;
    }
  }
  
  updateParticles(particleData) {
    const updateId = Date.now().toString();
    
    this.pendingUpdates.set(updateId, {
      type: 'particles',
      timestamp: Date.now()
    });
    
    this.worker.postMessage({
      type: 'UPDATE_PARTICLES',
      data: particleData
    });
  }
  
  applyParticleUpdate(updatedData) {
    const { positions, velocities, life } = updatedData;
    
    // Update the main thread state
    const { particles } = useSimulationStore.getState();
    
    particles.positions.set(positions);
    particles.velocities.set(velocities);
    particles.life.set(life);
  }
}
```

## Conclusion

High-frequency state management is critical for maintaining 60 FPS performance in complex visualization systems. The key strategies include:

1. **Frequency-Based Separation**: Different update rates for different types of data
2. **Non-Reactive Updates**: Using refs and direct manipulation to avoid re-renders
3. **Batched Processing**: Efficient handling of multiple updates per frame
4. **Memory Efficiency**: Using typed arrays and buffers for performance
5. **Web Workers**: Offloading computation to separate threads

These techniques enable the creation of smooth, responsive visualization systems that can handle complex simulations while maintaining excellent user experience.