# Auto-Fitting Camera Algorithms

## Overview

Auto-fitting camera algorithms automatically adjust the camera position and orientation to ensure all relevant network nodes and connections are visible within the viewport. This research explores the mathematical foundations and implementation strategies for intelligent camera framing in geospatial visualization systems.

## Mathematical Foundation

### Bounding Volume Calculation

#### 3D Bounding Sphere
```javascript
function calculateBoundingSphere(positions) {
  // Find the minimal bounding sphere for a set of 3D points
  let center = new THREE.Vector3();
  let radius = 0;
  
  // Initial approximation: use centroid
  for (const pos of positions) {
    center.add(pos);
  }
  center.divideScalar(positions.length);
  
  // Find maximum distance from center
  for (const pos of positions) {
    radius = Math.max(radius, pos.distanceTo(center));
  }
  
  // Refine using iterative approach
  const iterations = 10;
  for (let i = 0; i < iterations; i++) {
    let farthestPoint = null;
    let maxDistance = radius;
    
    for (const pos of positions) {
      const distance = pos.distanceTo(center);
      if (distance > maxDistance) {
        maxDistance = distance;
        farthestPoint = pos;
      }
    }
    
    if (farthestPoint) {
      // Move center toward farthest point
      const direction = farthestPoint.clone().sub(center).normalize();
      center.add(direction.multiplyScalar((maxDistance - radius) * 0.1));
      radius = maxDistance;
    }
  }
  
  return { center, radius };
}
```

#### 2D Bounding Box
```javascript
function calculateBoundingBox2D(positions) {
  let minX = Infinity, maxX = -Infinity;
  let minY = Infinity, maxY = -Infinity;
  
  for (const pos of positions) {
    minX = Math.min(minX, pos.x);
    maxX = Math.max(maxX, pos.x);
    minY = Math.min(minY, pos.y);
    maxY = Math.max(maxY, pos.y);
  }
  
  const center = new THREE.Vector2(
    (minX + maxX) / 2,
    (minY + maxY) / 2
  );
  
  const size = new THREE.Vector2(
    maxX - minX,
    maxY - minY
  );
  
  return { center, size };
}
```

### Camera Distance Calculation

#### Perspective Camera Distance
```javascript
function calculateCameraDistance(boundingRadius, fov, aspectRatio, padding = 1.2) {
  const fovRad = fov * Math.PI / 180;
  
  // Distance to fit sphere vertically
  const verticalDistance = boundingRadius / Math.sin(fovRad / 2);
  
  // Distance to fit sphere horizontally
  const horizontalFov = 2 * Math.atan(Math.tan(fovRad / 2) * aspectRatio);
  const horizontalDistance = boundingRadius / Math.sin(horizontalFov / 2);
  
  // Use the larger distance
  const distance = Math.max(verticalDistance, horizontalDistance) * padding;
  
  return distance;
}
```

#### Orthographic Camera Zoom
```javascript
function calculateOrthographicZoom(boundingBox, viewportSize, padding = 1.1) {
  const { size } = boundingBox;
  
  // Calculate required zoom to fit the bounds
  const horizontalZoom = viewportSize.width / (size.x * padding);
  const verticalZoom = viewportSize.height / (size.y * padding);
  
  // Use the smaller zoom (fits both dimensions)
  return Math.min(horizontalZoom, verticalZoom);
}
```

## 3D Auto-Fit Algorithm

### Spherical Coordinates Approach

```javascript
class AutoFitCamera3D {
  constructor(camera, scene) {
    this.camera = camera;
    this.scene = scene;
    this.targetPosition = new THREE.Vector3();
    this.targetLookAt = new THREE.Vector3();
    this.currentPosition = camera.position.clone();
    this.currentLookAt = new THREE.Vector3(0, 0, 0);
    
    this.damping = 0.05;
    this.minDistance = 1.5;
    this.maxDistance = 10;
  }
  
  fitToNodes(nodeIds, transitionDuration = 1000) {
    if (nodeIds.length === 0) return;
    
    // Get node positions
    const positions = nodeIds.map(nodeId => {
      const node = networkGraph.nodes.get(nodeId);
      return latLonToCartesian(
        node.position.lat,
        node.position.lon,
        1.0 // radius
      );
    });
    
    // Calculate bounding sphere
    const boundingSphere = calculateBoundingSphere(positions);
    
    // Calculate optimal camera position
    const distance = calculateCameraDistance(
      boundingSphere.radius,
      this.camera.fov,
      this.camera.aspect
    );
    
    // Position camera along vector from sphere center
    const cameraDirection = this.camera.position.clone().sub(boundingSphere.center).normalize();
    const newPosition = boundingSphere.center.clone().add(
      cameraDirection.multiplyScalar(Math.max(distance, this.minDistance))
    );
    
    // Set targets for smooth interpolation
    this.targetPosition.copy(newPosition);
    this.targetLookAt.copy(boundingSphere.center);
    
    // Start transition
    this.startTransition(transitionDuration);
  }
  
  startTransition(duration) {
    const startPosition = this.currentPosition.clone();
    const startLookAt = this.currentLookAt.clone();
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      
      // Smooth easing
      const easedProgress = this.easeInOutCubic(progress);
      
      // Interpolate position
      this.currentPosition.lerpVectors(startPosition, this.targetPosition, easedProgress);
      this.currentLookAt.lerpVectors(startLookAt, this.targetLookAt, easedProgress);
      
      // Update camera
      this.camera.position.copy(this.currentPosition);
      this.camera.lookAt(this.currentLookAt);
      
      if (progress < 1) {
        requestAnimationFrame(animate);
      }
    };
    
    animate();
  }
  
  easeInOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }
  
  update(deltaTime) {
    // Continuous damping toward target
    this.currentPosition.lerp(this.targetPosition, this.damping);
    this.currentLookAt.lerp(this.targetLookAt, this.damping);
    
    this.camera.position.copy(this.currentPosition);
    this.camera.lookAt(this.currentLookAt);
  }
}
```

## 2D Auto-Fit Algorithm

### Planar Projection Approach

```javascript
class AutoFitCamera2D {
  constructor(camera, scene, globe) {
    this.camera = camera;
    this.scene = scene;
    this.globe = globe;
    this.targetZoom = 1;
    this.currentZoom = 1;
    this.targetCenter = new THREE.Vector2();
    this.currentCenter = new THREE.Vector2();
    
    this.damping = 0.1;
  }
  
  fitToNodes(nodeIds, transitionDuration = 1000) {
    if (nodeIds.length === 0) return;
    
    // Convert geographic coordinates to planar
    const planarPositions = nodeIds.map(nodeId => {
      const node = networkGraph.nodes.get(nodeId);
      return this.geographicToPlanar(node.position.lat, node.position.lon);
    });
    
    // Calculate bounding box
    const boundingBox = calculateBoundingBox2D(planarPositions);
    
    // Calculate optimal zoom and center
    const viewportSize = {
      width: window.innerWidth,
      height: window.innerHeight
    };
    
    this.targetZoom = calculateOrthographicZoom(boundingBox, viewportSize);
    this.targetCenter.copy(boundingBox.center);
    
    // Start transition
    this.startTransition(transitionDuration);
  }
  
  geographicToPlanar(lat, lon) {
    // Equirectangular projection
    const x = (lon / 180) * Math.PI;
    const y = (lat / 90) * Math.PI / 2;
    
    return new THREE.Vector2(x, y);
  }
  
  startTransition(duration) {
    const startZoom = this.currentZoom;
    const startCenter = this.currentCenter.clone();
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easedProgress = this.easeInOutCubic(progress);
      
      // Interpolate zoom
      this.currentZoom = startZoom + (this.targetZoom - startZoom) * easedProgress;
      
      // Interpolate center
      this.currentCenter.lerpVectors(startCenter, this.targetCenter, easedProgress);
      
      // Update camera
      this.updateCamera();
      
      if (progress < 1) {
        requestAnimationFrame(animate);
      }
    };
    
    animate();
  }
  
  updateCamera() {
    // Update orthographic camera zoom and position
    const halfWidth = window.innerWidth / (2 * this.currentZoom);
    const halfHeight = window.innerHeight / (2 * this.currentZoom);
    
    this.camera.left = -halfWidth + this.currentCenter.x;
    this.camera.right = halfWidth + this.currentCenter.x;
    this.camera.top = halfHeight + this.currentCenter.y;
    this.camera.bottom = -halfHeight + this.currentCenter.y;
    
    this.camera.updateProjectionMatrix();
  }
  
  easeInOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  }
  
  update(deltaTime) {
    // Continuous damping
    this.currentZoom += (this.targetZoom - this.currentZoom) * this.damping;
    this.currentCenter.lerp(this.targetCenter, this.damping);
    
    this.updateCamera();
  }
}
```

## Hybrid 3D/2D Auto-Fit

### Adaptive Algorithm for Morphing Globe

```javascript
class HybridAutoFitCamera {
  constructor(camera3D, camera2D, scene) {
    this.camera3D = camera3D;
    this.camera2D = camera2D;
    this.scene = scene;
    this.currentMode = '3D'; // or '2D'
    this.mixFactor = 0; // 0 = 3D, 1 = 2D
    
    this.autoFit3D = new AutoFitCamera3D(camera3D, scene);
    this.autoFit2D = new AutoFitCamera2D(camera2D, scene);
  }
  
  fitToNodes(nodeIds, transitionDuration = 1000) {
    if (this.currentMode === '3D') {
      this.autoFit3D.fitToNodes(nodeIds, transitionDuration);
    } else {
      this.autoFit2D.fitToNodes(nodeIds, transitionDuration);
    }
  }
  
  transitionToMode(targetMode, duration = 1000) {
    if (this.currentMode === targetMode) return;
    
    const startMode = this.currentMode;
    const startTime = Date.now();
    
    const animate = () => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const easedProgress = this.easeInOutCubic(progress);
      
      if (targetMode === '2D') {
        this.mixFactor = easedProgress;
      } else {
        this.mixFactor = 1 - easedProgress;
      }
      
      // Blend camera parameters
      this.blendCameras(easedProgress, startMode, targetMode);
      
      if (progress < 1) {
        requestAnimationFrame(animate);
      } else {
        this.currentMode = targetMode;
      }
    };
    
    animate();
  }
  
  blendCameras(progress, fromMode, toMode) {
    if (fromMode === '3D' && toMode === '2D') {
      // Transition from 3D to 2D
      this.camera3D.camera.position.z = THREE.MathUtils.lerp(
        this.camera3D.camera.position.z,
        this.camera3D.maxDistance,
        progress
      );
      
      this.camera3D.camera.fov = THREE.MathUtils.lerp(
        this.camera3D.camera.fov,
        10, // Narrow FOV for orthographic-like view
        progress
      );
      
      this.camera3D.camera.updateProjectionMatrix();
    }
  }
  
  update(deltaTime) {
    if (this.currentMode === '3D') {
      this.autoFit3D.update(deltaTime);
    } else {
      this.autoFit2D.update(deltaTime);
    }
  }
}
```

## Smart Focus Algorithms

### Weighted Focus Points

```javascript
class SmartFocus {
  constructor() {
    this.focusWeights = new Map();
    this.focusStrategies = new Map();
  }
  
  addFocusStrategy(name, strategy) {
    this.focusStrategies.set(name, strategy);
  }
  
  calculateWeightedFocus(nodes, strategy = 'default') {
    const focusStrategy = this.focusStrategies.get(strategy);
    if (!focusStrategy) return null;
    
    return focusStrategy.calculate(nodes, this.focusWeights);
  }
}

// Connection density focus
const connectionDensityStrategy = {
  calculate(nodes, weights) {
    const positionCounts = new Map();
    
    // Count connections per region
    for (const node of nodes) {
      const region = this.getRegion(node.position);
      positionCounts.set(region, (positionCounts.get(region) || 0) + 1);
    }
    
    // Find region with highest density
    let maxDensity = 0;
    let focusRegion = null;
    
    for (const [region, count] of positionCounts) {
      if (count > maxDensity) {
        maxDensity = count;
        focusRegion = region;
      }
    }
    
    return focusRegion;
  },
  
  getRegion(position) {
    // Simple grid-based region classification
    const gridSize = 10; // degrees
    const gridX = Math.floor(position.lon / gridSize);
    const gridY = Math.floor(position.lat / gridSize);
    
    return `${gridX},${gridY}`;
  }
};

// Critical path focus
const criticalPathStrategy = {
  calculate(nodes, weights) {
    // Find nodes that are part of critical paths
    const criticalNodes = new Set();
    
    for (const node of nodes) {
      if (this.isOnCriticalPath(node)) {
        criticalNodes.add(node);
      }
    }
    
    return this.calculateCentroid(Array.from(criticalNodes));
  },
  
  isOnCriticalPath(node) {
    // Check if node is part of any critical network path
    // This would involve network topology analysis
    return node.connections > 5; // Simple heuristic
  },
  
  calculateCentroid(nodes) {
    const center = new THREE.Vector3();
    
    for (const node of nodes) {
      const position = latLonToCartesian(
        node.position.lat,
        node.position.lon,
        1.0
      );
      center.add(position);
    }
    
    center.divideScalar(nodes.length);
    return center;
  }
};
```

## Performance Considerations

### Efficient Bounds Calculation

```javascript
class EfficientBounds {
  constructor() {
    this.boundsCache = new Map();
    this.cacheExpiry = 5000; // 5 seconds
  }
  
  calculateBounds(nodeIds) {
    const cacheKey = nodeIds.sort().join(',');
    const cached = this.boundsCache.get(cacheKey);
    
    if (cached && Date.now() - cached.timestamp < this.cacheExpiry) {
      return cached.bounds;
    }
    
    const bounds = this.computeBounds(nodeIds);
    
    this.boundsCache.set(cacheKey, {
      bounds,
      timestamp: Date.now()
    });
    
    return bounds;
  }
  
  computeBounds(nodeIds) {
    const positions = nodeIds.map(nodeId => {
      const node = networkGraph.nodes.get(nodeId);
      return latLonToCartesian(
        node.position.lat,
        node.position.lon,
        1.0
      );
    });
    
    return calculateBoundingSphere(positions);
  }
  
  invalidateCache() {
    this.boundsCache.clear();
  }
}
```

### Adaptive Update Frequency

```javascript
class AdaptiveCameraUpdate {
  constructor() {
    this.updateFrequency = 60; // Start at 60 FPS
    this.performanceHistory = [];
    this.maxHistoryLength = 10;
  }
  
  recordFrameTime(frameTime) {
    this.performanceHistory.push(frameTime);
    
    if (this.performanceHistory.length > this.maxHistoryLength) {
      this.performanceHistory.shift();
    }
    
    this.adjustUpdateFrequency();
  }
  
  adjustUpdateFrequency() {
    const avgFrameTime = this.performanceHistory.reduce((a, b) => a + b) / this.performanceHistory.length;
    
    if (avgFrameTime > 20) { // > 20ms = < 50 FPS
      this.updateFrequency = Math.max(30, this.updateFrequency * 0.9);
    } else if (avgFrameTime < 15) { // < 15ms = > 66 FPS
      this.updateFrequency = Math.min(60, this.updateFrequency * 1.1);
    }
  }
  
  shouldUpdate(frameCount) {
    return frameCount % Math.floor(60 / this.updateFrequency) === 0;
  }
}
```

## Conclusion

Auto-fitting camera algorithms are essential for creating intuitive and user-friendly geospatial visualization systems. The key to success lies in:

1. **Accurate Bounds Calculation**: Efficient algorithms for finding optimal camera positions
2. **Smooth Transitions**: Comfortable easing functions and appropriate timing
3. **Adaptive Strategies**: Different approaches for 3D and 2D modes
4. **Performance Optimization**: Caching and adaptive update frequencies
5. **Smart Focus**: Intelligent algorithms that understand network topology

The techniques presented here enable the creation of professional-grade camera systems that enhance user experience and provide clear, comprehensive views of complex network data.