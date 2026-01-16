# Network Topology Rendering

## Overview

Network topology rendering for the Cyber-Physical Globe involves visualizing complex network connections, server relationships, and data flow patterns in a geographically contextualized manner. This research explores the technical approaches for creating dynamic, informative network visualizations that scale to thousands of connections while maintaining 60 FPS performance.

## Network Data Models

### Graph Representation

```javascript
class NetworkGraph {
  constructor() {
    this.nodes = new Map(); // Servers/Devices
    this.edges = new Map(); // Connections
    this.adjacencyList = new Map();
  }
  
  addNode(id, properties) {
    const node = {
      id,
      position: properties.position, // {lat, lon}
      type: properties.type || 'server',
      status: properties.status || 'active',
      metadata: properties.metadata || {}
    };
    
    this.nodes.set(id, node);
    this.adjacencyList.set(id, new Set());
  }
  
  addEdge(sourceId, targetId, properties) {
    const edge = {
      id: `${sourceId}-${targetId}`,
      source: sourceId,
      target: targetId,
      weight: properties.weight || 1,
      latency: properties.latency || 0,
      bandwidth: properties.bandwidth || 0,
      status: properties.status || 'active',
      protocol: properties.protocol || 'tcp'
    };
    
    this.edges.set(edge.id, edge);
    this.adjacencyList.get(sourceId).add(targetId);
    this.adjacencyList.get(targetId).add(sourceId); // For undirected graph
  }
}
```

### Network Topology Types

#### Hierarchical Topology
```javascript
class HierarchicalTopology {
  constructor() {
    this.rootNodes = new Set();
    this.levels = new Map();
  }
  
  addNode(nodeId, level, parentId = null) {
    if (!this.levels.has(level)) {
      this.levels.set(level, new Set());
    }
    
    this.levels.get(level).add(nodeId);
    
    if (parentId) {
      networkGraph.addEdge(parentId, nodeId, { type: 'hierarchy' });
    } else {
      this.rootNodes.add(nodeId);
    }
  }
  
  getNodesAtLevel(level) {
    return this.levels.get(level) || new Set();
  }
  
  getLevel(nodeId) {
    for (const [level, nodes] of this.levels) {
      if (nodes.has(nodeId)) return level;
    }
    return -1;
  }
}
```

#### Mesh Topology
```javascript
class MeshTopology {
  constructor() {
    this.clusters = new Map();
  }
  
  createCluster(clusterId, nodeIds) {
    this.clusters.set(clusterId, {
      nodes: new Set(nodeIds),
      connections: this.generateMeshConnections(nodeIds)
    });
  }
  
  generateMeshConnections(nodeIds) {
    const connections = [];
    
    for (let i = 0; i < nodeIds.length; i++) {
      for (let j = i + 1; j < nodeIds.length; j++) {
        connections.push({
          source: nodeIds[i],
          target: nodeIds[j],
          weight: Math.random() // Simulate connection strength
        });
      }
    }
    
    return connections;
  }
  
  connectClusters(clusterId1, clusterId2, connections) {
    const cluster1 = this.clusters.get(clusterId1);
    const cluster2 = this.clusters.get(clusterId2);
    
    connections.forEach(conn => {
      if (cluster1.nodes.has(conn.from) && cluster2.nodes.has(conn.to)) {
        networkGraph.addEdge(conn.from, conn.to, {
          type: 'inter-cluster',
          weight: conn.weight
        });
      }
    });
  }
}
```

#### Star Topology
```javascript
class StarTopology {
  constructor() {
    this.centers = new Map();
  }
  
  createStar(centerId, satelliteIds) {
    this.centers.set(centerId, new Set(satelliteIds));
    
    satelliteIds.forEach(satelliteId => {
      networkGraph.addEdge(centerId, satelliteId, {
        type: 'star',
        weight: 1
      });
    });
  }
  
  getSatellites(centerId) {
    return this.centers.get(centerId) || new Set();
  }
  
  getCenter(satelliteId) {
    for (const [centerId, satellites] of this.centers) {
      if (satellites.has(satelliteId)) return centerId;
    }
    return null;
  }
}
```

## Visual Encoding Strategies

### Node Representation

#### Hierarchical Node Sizing
```javascript
function calculateNodeSize(nodeId, topologyType) {
  const baseSize = 0.1;
  
  switch (topologyType) {
    case 'hierarchical':
      const level = hierarchicalTopology.getLevel(nodeId);
      return baseSize * Math.pow(1.5, level);
      
    case 'mesh':
      const connections = networkGraph.adjacencyList.get(nodeId).size;
      return baseSize * Math.log2(connections + 1);
      
    case 'star':
      const center = starTopology.getCenter(nodeId);
      return center ? baseSize * 0.7 : baseSize * 1.3;
      
    default:
      return baseSize;
  }
}
```

#### Status-Based Coloring
```javascript
const NODE_COLORS = {
  active: 0x00ff00,    // Green
  warning: 0xffaa00,   // Orange
  error: 0xff0000,     // Red
  unknown: 0x888888,   // Gray
  maintenance: 0x00aaff // Blue
};

function getNodeColor(nodeId) {
  const node = networkGraph.nodes.get(nodeId);
  return NODE_COLORS[node.status] || NODE_COLORS.unknown;
}
```

### Edge Representation

#### Connection Weight Visualization
```javascript
function calculateEdgeWidth(edgeId) {
  const edge = networkGraph.edges.get(edgeId);
  const baseWidth = 0.01;
  
  // Scale based on bandwidth or weight
  const scale = Math.log10(edge.bandwidth || edge.weight || 1) / 3;
  return baseWidth * Math.max(0.5, Math.min(3, scale));
}
```

#### Latency-Based Animation Speed
```javascript
function calculateAnimationSpeed(latency) {
  // Base speed: 100ms latency = 1x speed
  const baseSpeed = 1;
  const latencyFactor = 100 / (latency || 100);
  
  return baseSpeed * Math.max(0.1, Math.min(5, latencyFactor));
}
```

## Dynamic Network Updates

### Real-Time Data Integration

```javascript
class NetworkDataAdapter {
  constructor() {
    this.eventSource = null;
    this.updateQueue = [];
    this.processingInterval = null;
  }
  
  connect(dataSource) {
    this.eventSource = new EventSource(dataSource);
    
    this.eventSource.addEventListener('node-update', (event) => {
      const update = JSON.parse(event.data);
      this.updateQueue.push({ type: 'node', data: update });
    });
    
    this.eventSource.addEventListener('edge-update', (event) => {
      const update = JSON.parse(event.data);
      this.updateQueue.push({ type: 'edge', data: update });
    });
    
    this.startProcessing();
  }
  
  startProcessing() {
    this.processingInterval = setInterval(() => {
      this.processUpdates();
    }, 16); // Process updates every frame (60 FPS)
  }
  
  processUpdates() {
    const maxUpdatesPerFrame = 10; // Prevent frame drops
    let processed = 0;
    
    while (this.updateQueue.length > 0 && processed < maxUpdatesPerFrame) {
      const update = this.updateQueue.shift();
      
      if (update.type === 'node') {
        this.updateNode(update.data);
      } else if (update.type === 'edge') {
        this.updateEdge(update.data);
      }
      
      processed++;
    }
  }
  
  updateNode(nodeData) {
    const node = networkGraph.nodes.get(nodeData.id);
    if (node) {
      Object.assign(node, nodeData.properties);
      
      // Trigger visual update
      this.notifyNodeUpdate(nodeData.id);
    }
  }
  
  updateEdge(edgeData) {
    const edge = networkGraph.edges.get(edgeData.id);
    if (edge) {
      Object.assign(edge, edgeData.properties);
      
      // Trigger visual update
      this.notifyEdgeUpdate(edgeData.id);
    }
  }
  
  notifyNodeUpdate(nodeId) {
    // Emit custom event for visual components
    window.dispatchEvent(new CustomEvent('node-updated', {
      detail: { nodeId }
    }));
  }
  
  notifyEdgeUpdate(edgeId) {
    window.dispatchEvent(new CustomEvent('edge-updated', {
      detail: { edgeId }
    }));
  }
}
```

### Batch Update Optimization

```javascript
class BatchUpdater {
  constructor() {
    this.pendingUpdates = new Map();
    this.batchTimer = null;
    this.batchSize = 100;
    this.batchDelay = 50; // 50ms batching window
  }
  
  addUpdate(type, id, data) {
    if (!this.pendingUpdates.has(type)) {
      this.pendingUpdates.set(type, new Map());
    }
    
    this.pendingUpdates.get(type).set(id, data);
    
    if (!this.batchTimer) {
      this.batchTimer = setTimeout(() => {
        this.processBatch();
      }, this.batchDelay);
    }
  }
  
  processBatch() {
    const updates = this.pendingUpdates;
    this.pendingUpdates = new Map();
    this.batchTimer = null;
    
    // Process all pending updates
    for (const [type, updatesMap] of updates) {
      if (type === 'nodes') {
        this.batchUpdateNodes(updatesMap);
      } else if (type === 'edges') {
        this.batchUpdateEdges(updatesMap);
      }
    }
  }
  
  batchUpdateNodes(updates) {
    const updateArray = Array.from(updates.entries());
    
    for (let i = 0; i < updateArray.length; i += this.batchSize) {
      const batch = updateArray.slice(i, i + this.batchSize);
      
      // Process batch
      requestAnimationFrame(() => {
        batch.forEach(([nodeId, data]) => {
          const node = networkGraph.nodes.get(nodeId);
          if (node) {
            Object.assign(node, data);
          }
        });
        
        // Trigger single visual update for batch
        this.notifyBatchUpdate('nodes', batch.map(([id]) => id));
      });
    }
  }
}
```

## Performance Optimization

### Spatial Indexing

#### Quadtree for Geographic Data
```javascript
class GeographicQuadtree {
  constructor(bounds, maxDepth = 8) {
    this.bounds = bounds; // {minLat, maxLat, minLon, maxLon}
    this.maxDepth = maxDepth;
    this.nodes = new Map();
    this.quadtree = this.createQuadtree();
  }
  
  createQuadtree() {
    // Implementation of quadtree for geographic coordinates
    return new Quadtree({
      width: this.bounds.maxLon - this.bounds.minLon,
      height: this.bounds.maxLat - this.bounds.minLat,
      x: this.bounds.minLon,
      y: this.bounds.minLat,
      maxObjects: 10,
      maxLevels: this.maxDepth
    });
  }
  
  insertNode(nodeId, lat, lon) {
    this.quadtree.insert({
      x: lon,
      y: lat,
      nodeId: nodeId
    });
  }
  
  getNodesInBounds(bounds) {
    return this.quadtree.retrieve(bounds);
  }
  
  getVisibleNodes(viewportBounds) {
    return this.getNodesInBounds(viewportBounds);
  }
}
```

### Visibility Culling

#### Frustum Culling for Network Elements
```javascript
class NetworkCullingManager {
  constructor() {
    this.frustum = new THREE.Frustum();
    this.cameraMatrix = new THREE.Matrix4();
    this.visibleNodes = new Set();
    this.visibleEdges = new Set();
  }
  
  updateVisibility(camera) {
    this.cameraMatrix.multiplyMatrices(
      camera.projectionMatrix,
      camera.matrixWorldInverse
    );
    this.frustum.setFromProjectionMatrix(this.cameraMatrix);
    
    // Cull nodes
    this.visibleNodes.clear();
    for (const [nodeId, node] of networkGraph.nodes) {
      const position = latLonToCartesian(
        node.position.lat,
        node.position.lon,
        1 // radius
      );
      
      if (this.frustum.containsPoint(position)) {
        this.visibleNodes.add(nodeId);
      }
    }
    
    // Cull edges (both endpoints must be visible)
    this.visibleEdges.clear();
    for (const [edgeId, edge] of networkGraph.edges) {
      if (this.visibleNodes.has(edge.source) && 
          this.visibleNodes.has(edge.target)) {
        this.visibleEdges.add(edgeId);
      }
    }
  }
  
  getVisibleElements() {
    return {
      nodes: this.visibleNodes,
      edges: this.visibleEdges
    };
  }
}
```

### Level of Detail (LOD)

```javascript
class NetworkLOD {
  constructor() {
    this.lodLevels = new Map();
    this.distanceThresholds = [0, 100, 500, 1000, 2000]; // km
  }
  
  createLODLevels() {
    // Level 0: Full detail (closest)
    this.lodLevels.set(0, {
      nodeDetail: 'full',
      edgeDetail: 'full',
      showLabels: true,
      showParticles: true
    });
    
    // Level 1: Reduced detail
    this.lodLevels.set(1, {
      nodeDetail: 'medium',
      edgeDetail: 'medium',
      showLabels: false,
      showParticles: true
    });
    
    // Level 2: Low detail
    this.lodLevels.set(2, {
      nodeDetail: 'low',
      edgeDetail: 'low',
      showLabels: false,
      showParticles: false
    });
    
    // Level 3: Minimal detail (farthest)
    this.lodLevels.set(3, {
      nodeDetail: 'minimal',
      edgeDetail: 'none',
      showLabels: false,
      showParticles: false
    });
  }
  
  getLODLevel(distance) {
    for (let i = 0; i < this.distanceThresholds.length; i++) {
      if (distance < this.distanceThresholds[i]) {
        return this.lodLevels.get(i - 1) || this.lodLevels.get(0);
      }
    }
    return this.lodLevels.get(this.lodLevels.size - 1);
  }
}
```

## Interactive Features

### Node Selection and Highlighting

```javascript
class NetworkInteraction {
  constructor(scene, camera) {
    this.scene = scene;
    this.camera = camera;
    this.raycaster = new THREE.Raycaster();
    this.mouse = new THREE.Vector2();
    this.selectedNodes = new Set();
    this.highlightedNodes = new Set();
  }
  
  onMouseMove(event) {
    // Update mouse position
    this.mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
    this.mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
    
    // Raycast for node intersection
    this.raycaster.setFromCamera(this.mouse, this.camera);
    
    const nodeMeshes = this.getNodeMeshes();
    const intersects = this.raycaster.intersectObjects(nodeMeshes);
    
    if (intersects.length > 0) {
      const intersectedNode = intersects[0].object.userData.nodeId;
      this.highlightNode(intersectedNode);
    } else {
      this.clearHighlights();
    }
  }
  
  highlightNode(nodeId) {
    this.clearHighlights();
    this.highlightedNodes.add(nodeId);
    
    // Highlight the node and its connections
    this.highlightConnectedEdges(nodeId);
    
    // Show node information
    this.showNodeInfo(nodeId);
  }
  
  highlightConnectedEdges(nodeId) {
    for (const [edgeId, edge] of networkGraph.edges) {
      if (edge.source === nodeId || edge.target === nodeId) {
        // Highlight edge
        const edgeMesh = this.getEdgeMesh(edgeId);
        if (edgeMesh) {
          edgeMesh.material.emissive.setHex(0x444444);
        }
      }
    }
  }
  
  showNodeInfo(nodeId) {
    const node = networkGraph.nodes.get(nodeId);
    // Display node information in UI
    console.log('Node Info:', node);
  }
}
```

### Connection Path Tracing

```javascript
class PathTracer {
  constructor() {
    this.activeTraces = new Map();
  }
  
  startTrace(sourceId, targetId) {
    const path = this.findShortestPath(sourceId, targetId);
    if (!path) return null;
    
    const trace = {
      id: `trace-${Date.now()}`,
      path,
      progress: 0,
      speed: 0.1 // units per frame
    };
    
    this.activeTraces.set(trace.id, trace);
    return trace.id;
  }
  
  findShortestPath(sourceId, targetId) {
    // Dijkstra's algorithm
    const distances = new Map();
    const previous = new Map();
    const unvisited = new Set(networkGraph.nodes.keys());
    
    // Initialize distances
    for (const nodeId of unvisited) {
      distances.set(nodeId, nodeId === sourceId ? 0 : Infinity);
    }
    
    while (unvisited.size > 0) {
      // Find unvisited node with smallest distance
      let current = null;
      let minDistance = Infinity;
      
      for (const nodeId of unvisited) {
        const distance = distances.get(nodeId);
        if (distance < minDistance) {
          minDistance = distance;
          current = nodeId;
        }
      }
      
      if (current === null || current === targetId) break;
      
      unvisited.delete(current);
      
      // Update distances to neighbors
      for (const neighborId of networkGraph.adjacencyList.get(current)) {
        if (!unvisited.has(neighborId)) continue;
        
        const edge = networkGraph.edges.get(`${current}-${neighborId}`) ||
                     networkGraph.edges.get(`${neighborId}-${current}`);
        
        const alt = distances.get(current) + (edge ? edge.weight : 1);
        
        if (alt < distances.get(neighborId)) {
          distances.set(neighborId, alt);
          previous.set(neighborId, current);
        }
      }
    }
    
    // Reconstruct path
    const path = [];
    let current = targetId;
    
    while (current !== undefined) {
      path.unshift(current);
      current = previous.get(current);
    }
    
    return path.length > 1 ? path : null;
  }
  
  updateTraces(deltaTime) {
    for (const [traceId, trace] of this.activeTraces) {
      trace.progress += trace.speed * deltaTime;
      
      if (trace.progress >= 1.0) {
        this.completeTrace(traceId);
      } else {
        this.updateTraceVisual(trace);
      }
    }
  }
  
  updateTraceVisual(trace) {
    // Update visual representation of trace
    const currentIndex = Math.floor(trace.progress * (trace.path.length - 1));
    const currentNode = trace.path[currentIndex];
    
    // Highlight current node
    const nodeMesh = this.getNodeMesh(currentNode);
    if (nodeMesh) {
      nodeMesh.material.emissive.setHex(0x00ff00);
    }
  }
}
```

## Conclusion

Network topology rendering for geospatial visualization requires a sophisticated combination of graph theory, spatial data structures, and performance optimization techniques. The key to success lies in:

1. **Efficient Data Structures**: Use appropriate graph representations and spatial indexing
2. **Dynamic Updates**: Implement batch processing and real-time data integration
3. **Performance Optimization**: Apply culling, LOD, and instanced rendering
4. **Interactive Features**: Provide meaningful user interaction and data exploration
5. **Visual Encoding**: Use appropriate visual channels to represent network properties

The techniques presented here enable the creation of scalable, performant network visualizations that provide deep insights into global connectivity patterns while maintaining smooth 60 FPS performance.