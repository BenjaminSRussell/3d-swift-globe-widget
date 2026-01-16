# Memory Management

## Overview

Effective memory management is crucial for maintaining 60 FPS performance in complex geospatial visualization systems. This research explores strategies for preventing memory leaks, optimizing resource usage, and implementing efficient garbage collection prevention techniques.

## Memory Architecture

### Memory Budget Allocation

```javascript
const MEMORY_BUDGET = {
  geometry: 200 * 1024 * 1024,    // 200MB for geometry
  textures: 100 * 1024 * 1024,     // 100MB for textures
  shaders: 50 * 1024 * 1024,       // 50MB for shader programs
  particleSystems: 100 * 1024 * 1024, // 100MB for particles
  audio: 20 * 1024 * 1024,         // 20MB for audio
  misc: 30 * 1024 * 1024,          // 30MB for misc data
  total: 500 * 1024 * 1024         // 500MB total budget
};

class MemoryManager {
  constructor() {
    this.usage = new Map();
    this.allocations = new Map();
    this.listeners = new Map();
    
    // Initialize usage tracking
    for (const category of Object.keys(MEMORY_BUDGET)) {
      this.usage.set(category, 0);
    }
  }
  
  allocate(category, size, id) {
    const currentUsage = this.usage.get(category) || 0;
    const budget = MEMORY_BUDGET[category];
    
    if (currentUsage + size > budget) {
      console.warn(`Memory budget exceeded for ${category}: ${currentUsage + size} > ${budget}`);
      return false;
    }
    
    this.usage.set(category, currentUsage + size);
    this.allocations.set(id, { category, size });
    
    this.notifyListeners('allocated', { category, size, id });
    return true;
  }
  
  deallocate(id) {
    const allocation = this.allocations.get(id);
    if (!allocation) return false;
    
    const currentUsage = this.usage.get(allocation.category);
    this.usage.set(allocation.category, currentUsage - allocation.size);
    
    this.allocations.delete(id);
    this.notifyListeners('deallocated', allocation);
    
    return true;
  }
  
  getUsage(category) {
    return this.usage.get(category) || 0;
  }
  
  getTotalUsage() {
    let total = 0;
    for (const usage of this.usage.values()) {
      total += usage;
    }
    return total;
  }
  
  addListener(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event).add(callback);
  }
  
  notifyListeners(event, data) {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      for (const callback of callbacks) {
        callback(data);
      }
    }
  }
}
```

## Geometry Memory Management

### Automatic Geometry Disposal

```javascript
class GeometryManager {
  constructor(memoryManager) {
    this.memoryManager = memoryManager;
    this.geometries = new Map();
    this.disposalQueue = [];
    this.disposalInterval = null;
    
    this.startDisposalTimer();
  }
  
  createGeometry(type, params, id) {
    let geometry;
    let estimatedSize = 0;
    
    switch (type) {
      case 'sphere':
        geometry = new THREE.SphereGeometry(
          params.radius,
          params.widthSegments || 32,
          params.heightSegments || 16
        );
        estimatedSize = this.estimateSphereSize(params);
        break;
        
      case 'plane':
        geometry = new THREE.PlaneGeometry(
          params.width,
          params.height,
          params.widthSegments || 1,
          params.heightSegments || 1
        );
        estimatedSize = this.estimatePlaneSize(params);
        break;
        
      case 'tube':
        geometry = new THREE.TubeGeometry(
          params.path,
          params.segments || 64,
          params.radius || 0.1,
          params.radialSegments || 8,
          params.closed || false
        );
        estimatedSize = this.estimateTubeSize(params);
        break;
        
      default:
        throw new Error(`Unknown geometry type: ${type}`);
    }
    
    // Register with memory manager
    if (this.memoryManager.allocate('geometry', estimatedSize, id)) {
      this.geometries.set(id, {
        geometry,
        size: estimatedSize,
        lastUsed: Date.now(),
        useCount: 0
      });
      
      return geometry;
    } else {
      geometry.dispose();
      return null;
    }
  }
  
  getGeometry(id) {
    const entry = this.geometries.get(id);
    if (entry) {
      entry.lastUsed = Date.now();
      entry.useCount++;
    }
    return entry ? entry.geometry : null;
  }
  
  disposeGeometry(id) {
    const entry = this.geometries.get(id);
    if (!entry) return false;
    
    // Dispose Three.js geometry
    entry.geometry.dispose();
    
    // Update memory manager
    this.memoryManager.deallocate(id);
    
    // Remove from tracking
    this.geometries.delete(id);
    
    return true;
  }
  
  disposeUnused(threshold = 60000) { // 1 minute threshold
    const now = Date.now();
    const toDispose = [];
    
    for (const [id, entry] of this.geometries) {
      if (now - entry.lastUsed > threshold) {
        toDispose.push(id);
      }
    }
    
    for (const id of toDispose) {
      this.disposeGeometry(id);
    }
    
    return toDispose.length;
  }
  
  estimateSphereSize(params) {
    const vertices = (params.widthSegments || 32) * (params.heightSegments || 16) * 6;
    const bytesPerVertex = 3 * 4 + 3 * 4 + 2 * 4; // position + normal + uv
    return vertices * bytesPerVertex;
  }
  
  estimatePlaneSize(params) {
    const vertices = (params.widthSegments || 1) * (params.heightSegments || 1) * 6;
    const bytesPerVertex = 3 * 4 + 3 * 4 + 2 * 4;
    return vertices * bytesPerVertex;
  }
  
  estimateTubeSize(params) {
    const vertices = (params.segments || 64) * (params.radialSegments || 8) * 6;
    const bytesPerVertex = 3 * 4 + 3 * 4 + 2 * 4;
    return vertices * bytesPerVertex;
  }
  
  startDisposalTimer() {
    this.disposalInterval = setInterval(() => {
      this.disposeUnused();
    }, 30000); // Check every 30 seconds
  }
  
  stopDisposalTimer() {
    if (this.disposalInterval) {
      clearInterval(this.disposalInterval);
      this.disposalInterval = null;
    }
  }
}
```

### Geometry Pooling

```javascript
class GeometryPool {
  constructor(geometryManager) {
    this.geometryManager = geometryManager;
    this.pools = new Map();
    this.activeGeometries = new Map();
  }
  
  createPool(name, type, params, initialSize = 10) {
    const pool = {
      type,
      params,
      available: [],
      active: 0,
      totalCreated: 0
    };
    
    this.pools.set(name, pool);
    
    // Pre-allocate geometries
    for (let i = 0; i < initialSize; i++) {
      const geometry = this.geometryManager.createGeometry(
        type, params, `${name}-${i}`
      );
      if (geometry) {
        pool.available.push(geometry);
        pool.totalCreated++;
      }
    }
    
    return pool;
  }
  
  acquire(name) {
    const pool = this.pools.get(name);
    if (!pool) return null;
    
    let geometry;
    
    if (pool.available.length > 0) {
      geometry = pool.available.pop();
    } else {
      // Create new geometry
      const id = `${name}-${pool.totalCreated++}`;
      geometry = this.geometryManager.createGeometry(
        pool.type, pool.params, id
      );
    }
    
    if (geometry) {
      pool.active++;
      this.activeGeometries.set(geometry.id || name, geometry);
    }
    
    return geometry;
  }
  
  release(geometry) {
    const poolName = this.findPoolForGeometry(geometry);
    if (!poolName) return false;
    
    const pool = this.pools.get(poolName);
    pool.available.push(geometry);
    pool.active--;
    
    // Reset geometry for reuse
    this.resetGeometry(geometry);
    
    return true;
  }
  
  findPoolForGeometry(geometry) {
    for (const [name, pool] of this.pools) {
      if (pool.available.includes(geometry)) {
        return name;
      }
    }
    return null;
  }
  
  resetGeometry(geometry) {
    // Reset transformation and other properties
    if (geometry instanceof THREE.BufferGeometry) {
      // Clear any custom attributes
      const attributes = Object.keys(geometry.attributes);
      for (const attr of attributes) {
        if (attr.startsWith('custom_')) {
          geometry.deleteAttribute(attr);
        }
      }
    }
  }
  
  getPoolStats() {
    const stats = new Map();
    
    for (const [name, pool] of this.pools) {
      stats.set(name, {
        available: pool.available.length,
        active: pool.active,
        totalCreated: pool.totalCreated,
        utilization: pool.active / (pool.active + pool.available.length)
      });
    }
    
    return stats;
  }
}
```

## Texture Memory Optimization

### Texture Compression and Resizing

```javascript
class TextureManager {
  constructor(memoryManager) {
    this.memoryManager = memoryManager;
    this.textures = new Map();
    this.loadingPromises = new Map();
    this.compressionFormats = this.detectCompressionFormats();
  }
  
  detectCompressionFormats() {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl');
    
    const formats = {
      s3tc: gl.getExtension('WEBGL_compressed_texture_s3tc'),
      etc1: gl.getExtension('WEBGL_compressed_texture_etc1'),
      astc: gl.getExtension('WEBGL_compressed_texture_astc'),
      pvrtc: gl.getExtension('WEBGL_compressed_texture_pvrtc')
    };
    
    return formats;
  }
  
  async loadTexture(url, options = {}) {
    const cacheKey = `${url}-${JSON.stringify(options)}`;
    
    // Check if already loading
    if (this.loadingPromises.has(cacheKey)) {
      return this.loadingPromises.get(cacheKey);
    }
    
    // Check if already loaded
    if (this.textures.has(cacheKey)) {
      return this.textures.get(cacheKey).texture;
    }
    
    const loadPromise = this.loadTextureInternal(url, options);
    this.loadingPromises.set(cacheKey, loadPromise);
    
    try {
      const texture = await loadPromise;
      this.loadingPromises.delete(cacheKey);
      return texture;
    } catch (error) {
      this.loadingPromises.delete(cacheKey);
      throw error;
    }
  }
  
  async loadTextureInternal(url, options) {
    const loader = new THREE.TextureLoader();
    
    // Apply loading options
    const texture = await new Promise((resolve, reject) => {
      loader.load(
        url,
        resolve,
        undefined,
        reject
      );
    });
    
    // Optimize texture based on options
    if (options.maxSize) {
      texture = this.resizeTexture(texture, options.maxSize);
    }
    
    if (options.format) {
      texture = this.convertFormat(texture, options.format);
    }
    
    // Calculate memory usage
    const estimatedSize = this.estimateTextureSize(texture);
    const id = `texture-${url}-${Date.now()}`;
    
    if (this.memoryManager.allocate('textures', estimatedSize, id)) {
      this.textures.set(id, {
        texture,
        size: estimatedSize,
        lastUsed: Date.now(),
        useCount: 0
      });
      
      return texture;
    } else {
      texture.dispose();
      return null;
    }
  }
  
  resizeTexture(texture, maxSize) {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    
    const width = Math.min(texture.image.width, maxSize);
    const height = Math.min(texture.image.height, maxSize);
    
    canvas.width = width;
    canvas.height = height;
    
    ctx.drawImage(texture.image, 0, 0, width, height);
    
    const resizedTexture = new THREE.CanvasTexture(canvas);
    texture.dispose();
    
    return resizedTexture;
  }
  
  convertFormat(texture, targetFormat) {
    // This would involve more complex WebGL operations
    // For now, we'll just return the original texture
    return texture;
  }
  
  estimateTextureSize(texture) {
    const width = texture.image.width || texture.image.videoWidth || 512;
    const height = texture.image.height || texture.image.videoHeight || 512;
    
    // Estimate based on format (RGBA = 4 bytes per pixel)
    const bytesPerPixel = 4;
    return width * height * bytesPerPixel;
  }
  
  disposeTexture(id) {
    const entry = this.textures.get(id);
    if (!entry) return false;
    
    entry.texture.dispose();
    this.memoryManager.deallocate(id);
    this.textures.delete(id);
    
    return true;
  }
}
```

## Shader Program Management

### Shader Compilation and Caching

```javascript
class ShaderManager {
  constructor(memoryManager) {
    this.memoryManager = memoryManager;
    this.programs = new Map();
    this.shaderCache = new Map();
    this.compileQueue = [];
  }
  
  createProgram(vertexShader, fragmentShader, uniforms = {}, id) {
    const cacheKey = this.generateCacheKey(vertexShader, fragmentShader);
    
    // Check cache first
    if (this.shaderCache.has(cacheKey)) {
      const cached = this.shaderCache.get(cacheKey);
      cached.lastUsed = Date.now();
      cached.useCount++;
      return cached.program;
    }
    
    // Compile new program
    const program = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms
    });
    
    const estimatedSize = this.estimateProgramSize(vertexShader, fragmentShader);
    
    if (this.memoryManager.allocate('shaders', estimatedSize, id)) {
      this.programs.set(id, {
        program,
        size: estimatedSize,
        cacheKey,
        lastUsed: Date.now(),
        useCount: 1
      });
      
      this.shaderCache.set(cacheKey, {
        program,
        lastUsed: Date.now(),
        useCount: 1
      });
      
      return program;
    } else {
      program.dispose();
      return null;
    }
  }
  
  generateCacheKey(vertexShader, fragmentShader) {
    return `${this.hashShader(vertexShader)}-${this.hashShader(fragmentShader)}`;
  }
  
  hashShader(shader) {
    // Simple hash function for shader source
    let hash = 0;
    for (let i = 0; i < shader.length; i++) {
      const char = shader.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString(16);
  }
  
  estimateProgramSize(vertexShader, fragmentShader) {
    // Rough estimate based on shader complexity
    const vertexComplexity = vertexShader.length / 1000;
    const fragmentComplexity = fragmentShader.length / 1000;
    
    return (vertexComplexity + fragmentComplexity) * 1024; // bytes
  }
  
  disposeProgram(id) {
    const entry = this.programs.get(id);
    if (!entry) return false;
    
    entry.program.dispose();
    this.memoryManager.deallocate(id);
    this.shaderCache.delete(entry.cacheKey);
    this.programs.delete(id);
    
    return true;
  }
  
  disposeUnused(threshold = 300000) { // 5 minutes
    const now = Date.now();
    const toDispose = [];
    
    for (const [id, entry] of this.programs) {
      if (now - entry.lastUsed > threshold) {
        toDispose.push(id);
      }
    }
    
    for (const id of toDispose) {
      this.disposeProgram(id);
    }
    
    return toDispose.length;
  }
}
```

## Garbage Collection Prevention

### Object Pooling Strategies

```javascript
class ObjectPool {
  constructor(createFn, resetFn, initialSize = 10) {
    this.createFn = createFn;
    this.resetFn = resetFn;
    this.pool = [];
    this.active = new Set();
    
    // Pre-populate pool
    for (let i = 0; i < initialSize; i++) {
      const obj = this.createFn();
      obj._poolId = i;
      this.pool.push(obj);
    }
  }
  
  acquire() {
    let obj;
    
    if (this.pool.length > 0) {
      obj = this.pool.pop();
    } else {
      // Create new object
      obj = this.createFn();
      obj._poolId = this.pool.length + this.active.size;
    }
    
    this.active.add(obj);
    return obj;
  }
  
  release(obj) {
    if (!this.active.has(obj)) {
      console.warn('Releasing object not from this pool');
      return false;
    }
    
    // Reset object state
    this.resetFn(obj);
    
    // Return to pool
    this.active.delete(obj);
    this.pool.push(obj);
    
    return true;
  }
  
  getStats() {
    return {
      available: this.pool.length,
      active: this.active.size,
      total: this.pool.length + this.active.size
    };
  }
  
  clear() {
    this.pool.length = 0;
    this.active.clear();
  }
}

// Vector3 pool for calculations
const vector3Pool = new ObjectPool(
  () => new THREE.Vector3(),
  (vec) => vec.set(0, 0, 0),
  100
);

// Matrix4 pool for transformations
const matrix4Pool = new ObjectPool(
  () => new THREE.Matrix4(),
  (mat) mat.identity(),
  50
);
```

### Memory Leak Detection

```javascript
class MemoryLeakDetector {
  constructor() {
    this.snapshots = [];
    this.objectCounts = new Map();
    this.monitoring = false;
  }
  
  startMonitoring() {
    this.monitoring = true;
    this.takeSnapshot('initial');
    
    this.monitorInterval = setInterval(() => {
      this.checkForLeaks();
    }, 5000);
  }
  
  stopMonitoring() {
    this.monitoring = false;
    if (this.monitorInterval) {
      clearInterval(this.monitorInterval);
    }
  }
  
  takeSnapshot(label) {
    const snapshot = {
      label,
      timestamp: Date.now(),
      memoryUsage: performance.memory ? {
        used: performance.memory.usedJSHeapSize,
        total: performance.memory.totalJSHeapSize,
        limit: performance.memory.jsHeapSizeLimit
      } : null,
      objectCounts: new Map(this.objectCounts)
    };
    
    this.snapshots.push(snapshot);
    
    // Keep only last 10 snapshots
    if (this.snapshots.length > 10) {
      this.snapshots.shift();
    }
    
    return snapshot;
  }
  
  trackObject(type, count = 1) {
    this.objectCounts.set(type, (this.objectCounts.get(type) || 0) + count);
  }
  
  untrackObject(type, count = 1) {
    this.objectCounts.set(type, Math.max(0, (this.objectCounts.get(type) || 0) - count));
  }
  
  checkForLeaks() {
    if (this.snapshots.length < 2) return;
    
    const recent = this.snapshots.slice(-5);
    const trends = this.analyzeTrends(recent);
    
    for (const [type, trend] of trends) {
      if (trend.growthRate > 0.1) { // 10% growth per snapshot
        console.warn(`Potential memory leak detected in ${type}: ${trend.growthRate * 100}% growth`);
        this.reportLeak(type, trend);
      }
    }
  }
  
  analyzeTrends(snapshots) {
    const trends = new Map();
    
    // Get all object types
    const types = new Set();
    for (const snapshot of snapshots) {
      for (const type of snapshot.objectCounts.keys()) {
        types.add(type);
      }
    }
    
    // Analyze trends for each type
    for (const type of types) {
      const counts = snapshots.map(s => s.objectCounts.get(type) || 0);
      const growthRate = this.calculateGrowthRate(counts);
      
      trends.set(type, {
        counts,
        growthRate,
        current: counts[counts.length - 1]
      });
    }
    
    return trends;
  }
  
  calculateGrowthRate(values) {
    if (values.length < 2) return 0;
    
    let totalGrowth = 0;
    for (let i = 1; i < values.length; i++) {
      const growth = (values[i] - values[i - 1]) / values[i - 1];
      totalGrowth += growth;
    }
    
    return totalGrowth / (values.length - 1);
  }
  
  reportLeak(type, trend) {
    console.group(`Memory Leak Report: ${type}`);
    console.log('Growth rate:', trend.growthRate * 100, '%');
    console.log('Current count:', trend.current);
    console.log('Historical counts:', trend.counts);
    console.groupEnd();
    
    // Could also send to analytics or monitoring service
  }
}
```

## Conclusion

Effective memory management is fundamental to achieving high-performance geospatial visualization. The key strategies include:

1. **Budget-Based Allocation**: Enforcing memory limits per resource category
2. **Automatic Disposal**: Implementing lifecycle management for Three.js resources
3. **Object Pooling**: Reusing objects to prevent garbage collection
4. **Texture Optimization**: Compression and resizing for memory efficiency
5. **Leak Detection**: Proactive monitoring and prevention of memory leaks

The techniques presented here enable the creation of robust, long-running visualization systems that maintain consistent performance without degrading over time.