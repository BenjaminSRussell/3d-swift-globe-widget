import SceneKit
import SwiftUI
import Metal
import Combine

/// High-performance graphics engine for 3D globe visualization
/// Enhanced for Phase 3: Network topology, particle physics, and night mode
/// Stage 6: Integrated MemoryManager, GeometryPool, and enhanced PerformanceMonitor for performance optimization
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class GraphicsEngine: ObservableObject {
    
    // MARK: - Modules
    @Published public var state = ApplicationState()
    public let networkService = NetworkService()
    
    // Stage 6: Performance optimization components
    private let memoryManager = MemoryManager()
    private let performanceMonitor = PerformanceMonitor()
    private let geometryPool = GeometryPool()
    
    private var arcSystem: ArcSystem?
    private var particleSystem: ParticleSystem?
    private var burstController: BurstController?
    private var cameraTransitionManager: EnhancedCameraTransitionManager?
    private var lodManager: LODManager?
    private var connectionFailurePhysics: ConnectionFailurePhysics?
    private var autoFitCameraSystem: AutoFitCameraSystem?
    private var orbitCameraSystem: OrbitCameraSystem?
    private var panCameraSystem: PanCameraSystem?
    private var zoomCameraSystem: ZoomCameraSystem?
    
    // MARK: - Scene Properties
    @Published public var scene = SCNScene()
    @Published public var frameRate: Double = 60.0
    @Published public var drawCallCount: Int = 0
    @Published public var isNightMode: Bool = true
    
    private var cameraNode: SCNNode?
    private var globeNode: SCNNode?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Monitoring
    private var performanceTimer: Timer?
    private var lastFrameTime: CFTimeInterval = 0
    
    // MARK: - Initialization
    public init() {
        setupScene()
        initializeModules()
        setupBindings()
        setupNightMode()
        
        // Stage 6: Initialize performance monitoring and optimization
        performanceMonitor.start()
        memoryManager.initialize()
        geometryPool.preallocateGeometries()
        
        // Initial data load
        networkService.loadData()
        startPerformanceMonitoring()
    }
    
    private func initializeModules() {
        self.arcSystem = ArcSystem(scene: scene)
        self.particleSystem = ParticleSystem(scene: scene)
        self.burstController = BurstController(particleSystem: particleSystem!)
        self.connectionFailurePhysics = ConnectionFailurePhysics(scene: scene)
        
        if let cam = cameraNode {
            self.cameraTransitionManager = EnhancedCameraTransitionManager(cameraNode: cam, scene: scene)
            self.lodManager = LODManager(cameraNode: cam)
            self.autoFitCameraSystem = AutoFitCameraSystem(cameraNode: cam, scene: scene)
            
            // Stage 5: Connect LOD manager to performance components
            lodManager?.setCameraNode(cam)
        }
        
        // Stage 6: Initialize performance optimization
        setupPerformanceOptimization()
    }
    
    // Stage 6: Performance optimization setup
    private func setupPerformanceOptimization() {
        // Initialize memory management
        memoryManager.initialize()
        
        // Preallocate geometries
        geometryPool.preallocateGeometries()
        
        // Connect performance monitoring to LOD system
        performanceMonitor.onPerformanceUpdate = { [weak self] fps, memory, cache in
            self?.handlePerformanceUpdate(fps: fps, memory: memory, cacheHitRate: cache)
        }
        
        // Setup memory pressure handling
        memoryManager.onMemoryWarning = { [weak self] in
            self?.handleMemoryWarning()
        }
    }
    
    // Stage 6: Performance update handling
    private func handlePerformanceUpdate(fps: Double, memory: Double, cacheHitRate: Double) {
        // Auto-adjust LOD based on performance
        if fps < 30 {
            lodManager?.enableAggressiveMode()
        } else if fps > 50 {
            lodManager?.disableAggressiveMode()
        }
        
        // Update performance metrics
        frameRate = fps
        drawCallCount = Int(memory) // Simplified for now
    }
    
    // Stage 6: Memory pressure handling
    private func handleMemoryWarning() {
        // Clear caches and reduce LOD
        geometryPool.clearCache()
        lodManager?.enableAggressiveMode()
        particleSystem?.setMaxParticleCount(50)
    }
    
    private func setupBindings() {
        // Bind state changes to visual updates
        state.$viewMode
            .sink { [weak self] mode in
                self?.handleViewModeChange(mode)
            }
            .store(in: &cancellables)
        
        // Bind network updates to arc system
        networkService.$connections
            .sink { [weak self] connections in
                self?.updateArcs(for: connections)
            }
            .store(in: &cancellables)
        
        // Bind night mode changes
        $isNightMode
            .sink { [weak self] nightMode in
                self?.updateForNightMode(nightMode)
            }
            .store(in: &cancellables)
        
        Timer.publish(every: 1.0/5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performLODUpdate()
            }
            .store(in: &cancellables)
    }
    
    private func performLODUpdate() {
        guard let globe = globeNode else { return }
        lodManager?.updateLOD(for: globe)
        // Update arcs LOD
        arcSystem?.updateLOD(cameraPosition: cameraNode?.position ?? SCNVector3Zero)
        // Update particles LOD
        particleSystem?.setMaxParticleCount(lodManager?.currentLODLevel.particleCount ?? 50)
    }
    
    // MARK: - Night Mode Setup
    
    private func setupNightMode() {
        updateForNightMode(true)
    }
    
    public func updateForNightMode(_ enabled: Bool) {
        isNightMode = enabled
        
        // Update scene background
        if enabled {
            scene.background.contents = createNightSkyGradient()
        } else {
            scene.background.contents = UniversalColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
        }
        
        // Update lighting for night mode
        setupNightModeLighting(enabled)
        
        // Update globe material for night mode
        updateGlobeForNightMode(enabled)
        
        // Update arc system
        arcSystem?.updateForNightMode(enabled)
        
        // Update all node materials
        updateAllMaterialsForNightMode(enabled)
    }
    
    private func createNightSkyGradient() -> UIImage {
        let size = CGSize(width: 1024, height: 1024)
        
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Create night sky gradient
            let colors = [
                UniversalColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1.0).cgColor,
                UniversalColor(red: 0.0, green: 0.0, blue: 0.05, alpha: 1.0).cgColor
            ]
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: colors as CFArray,
                                   locations: [0.0, 1.0])!
            
            cgContext.drawLinearGradient(gradient, 
                                       start: CGPoint(x: 0, y: 0), 
                                       end: CGPoint(x: 0, y: size.height), 
                                       options: [])
            
            // Add stars
            addStarsToContext(cgContext, size: size)
        }
        #else
        // macOS fallback
        return UniversalColor.black.createImage(size: size)
        #endif
    }
    
    #if canImport(UIKit)
    private func addStarsToContext(_ context: CGContext, size: CGSize) {
        context.setFillColor(UIColor.white.cgColor)
        
        // Add random stars
        for _ in 0..<200 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height)
            let starSize = CGFloat.random(in: 0.5...2.0)
            
            context.fillEllipse(in: CGRect(x: x, y: y, width: starSize, height: starSize))
        }
    }
    #endif
    
    private func setupNightModeLighting(_ enabled: Bool) {
        // Remove existing lights
        let lightsToRemove = scene.rootNode.childNodes.filter { $0.light != nil }
        for light in lightsToRemove {
            light.removeFromParentNode()
        }
        
        if enabled {
            // Night mode lighting - darker ambient with accent lights
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.color = UniversalColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)
            
            // Cool directional light
            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light!.type = .omni
            directionalLight.light!.color = UniversalColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0)
            directionalLight.position = SCNVector3(10, 10, 10)
            scene.rootNode.addChildNode(directionalLight)
            
            // Accent light for network elements
            let accentLight = SCNNode()
            accentLight.light = SCNLight()
            accentLight.light!.type = .spot
            accentLight.light!.color = UniversalColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.3)
            accentLight.position = SCNVector3(-5, 5, 5)
            accentLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(accentLight)
        } else {
            // Day mode lighting
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.color = UniversalColor(white: 0.3, alpha: 1.0)
            scene.rootNode.addChildNode(ambientLight)
            
            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light!.type = .omni
            directionalLight.light!.color = UniversalColor(white: 0.8, alpha: 1.0)
            directionalLight.position = SCNVector3(10, 10, 10)
            scene.rootNode.addChildNode(directionalLight)
        }
    }
    
    private func updateGlobeForNightMode(_ enabled: Bool) {
        guard let globeNode = globeNode else { return }
        
        let material = globeNode.geometry?.firstMaterial
        
        if enabled {
            // Night mode - dark globe with glowing grid
            material?.diffuse.contents = UniversalColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 0.8)
            material?.emission.contents = UniversalColor(red: 0.0, green: 0.3, blue: 0.5, alpha: 0.2)
            material?.emission.intensity = 0.5
        } else {
            // Day mode
            material?.diffuse.contents = UniversalColor.systemBlue.withAlphaComponent(0.8)
            material?.emission.contents = nil
        }
    }
    
    private func updateAllMaterialsForNightMode(_ enabled: Bool) {
        // Update all materials in the scene for night mode
        scene.rootNode.childNodes.forEach { node in
            updateNodeMaterial(node, nightMode: enabled)
        }
    }
    
    private func updateNodeMaterial(_ node: SCNNode, nightMode: Bool) {
        node.geometry?.materials.forEach { material in
            if nightMode {
                // Enhance emission for night mode
                if material.emission.contents == nil {
                    material.emission.contents = UniversalColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 0.1)
                }
                material.emission.intensity = (material.emission.intensity * 1.5) + 0.2
            } else {
                // Reduce emission for day mode
                material.emission.intensity *= 0.3
                if material.emission.intensity < 0.1 {
                    material.emission.contents = nil
                }
            }
        }
        
        // Recursively update child nodes
        node.childNodes.forEach { childNode in
            updateNodeMaterial(childNode, nightMode: nightMode)
        }
    }
    
    // MARK: - Stage 5 Camera System Methods
    
    /// Focus camera on specific node with auto-fitting
    public func focusCamera(on node: NetworkService.Node) {
        let pos = Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
        autoFitCameraSystem?.focusOnNode(at: pos, withRadius: 2.0)
    }
    
    /// Enable/disable auto-fitting
    public func setAutoFitEnabled(_ enabled: Bool) {
        autoFitCameraSystem?.setEnabled(enabled)
    }
    
    /// Set focus strategy
    public func setFocusStrategy(_ strategy: String) {
        switch strategy {
        case "Performance":
            autoFitCameraSystem?.setStrategy(.performance)
        case "Visual":
            autoFitCameraSystem?.setStrategy(.visual)
        case "Network":
            autoFitCameraSystem?.setStrategy(.network)
        default:
            autoFitCameraSystem?.setStrategy(.optimal)
        }
    }
    
    /// Handle gesture override
    public func setGestureOverride(_ enabled: Bool) {
        if enabled {
            autoFitCameraSystem?.pause()
        } else {
            autoFitCameraSystem?.resume()
        }
    }
    
    // MARK: - Network Visualization
    
    public func updateArcs(for connections: [NetworkService.Connection]) {
        arcSystem?.clearArcs()
        
        for conn in connections {
            guard let source = networkService.nodes.first(where: { $0.id == conn.sourceId }),
                  let target = networkService.nodes.first(where: { $0.id == conn.targetId }) else { continue }
            
            // Create arc with dynamic properties based on connection weight
            let arcProperties = Visualization.ArcSystem.ArcProperties(
                id: conn.id,
                sourceId: conn.sourceId,
                targetId: conn.targetId,
                weight: conn.weight,
                status: getConnectionStatus(for: conn),
                visualStyle: getVisualStyle(for: conn.weight)
            )
            
            arcSystem?.createArc(id: conn.id, from: (source.lat, source.lon), to: (target.lat, target.lon), 
                                properties: arcProperties)
            
            // Start data flow animation for active connections
            if shouldAnimateDataFlow(for: conn) {
                arcSystem?.startDataFlow(id: conn.id, speed: Float(conn.weight * 2.0))
            }
            
            // Add labels for better verification
            addCityLabel(idPath: source.id, lat: source.lat, lon: source.lon)
            addCityLabel(idPath: target.id, lat: target.lat, lon: target.lon)
        }
    }
    
    private func getConnectionStatus(for connection: NetworkService.Connection) -> ArcSystem.ConnectionStatus {
        // Determine connection status based on weight and other factors
        if connection.weight < 0.3 {
            return .failure
        } else if connection.weight < 0.6 {
            return .warning
        } else {
            return .active
        }
    }
    
    private func getVisualStyle(for weight: Double) -> ArcSystem.ArcVisualStyle {
        if weight > 0.8 {
            return .critical
        } else if weight > 0.6 {
            return .highPriority
        } else {
            return .default
        }
    }
    
    private func shouldAnimateDataFlow(for connection: NetworkService.Connection) -> Bool {
        return connection.weight > 0.4
    }
    
    // MARK: - Connection Failure Physics
    
    /// External trigger for connection failure with particle effects
    public func triggerConnectionFailure(at nodeId: String, type: ConnectionFailurePhysics.FailureType = .connectionLost) {
        guard let node = networkService.nodes.first(where: { $0.id == nodeId }) else { return }
        let pos = Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
        
        // Trigger particle physics
        connectionFailurePhysics?.triggerFailure(at: pos, type: type, nodeId: nodeId)
        
        // Create ripple effect
        connectionFailurePhysics?.createFailureRipple(at: pos, type: type)
        
        // Update arc status
        updateArcStatusForNode(nodeId, status: Visualization.ArcSystem.ConnectionStatus.failure)
        
        // Trigger burst controller
        burstController?.triggerFailureBurst(at: pos)
    }
    
    /// Triggers cascade failure for multiple nodes
    public func triggerCascadeFailure(nodeIds: [String]) {
        let positions: [(SCNVector3, ConnectionFailurePhysics.FailureType)] = nodeIds.compactMap { nodeId in
            guard let node = networkService.nodes.first(where: { $0.id == nodeId }) else { return nil }
            let pos = Math.GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
            return (pos, ConnectionFailurePhysics.FailureType.connectionLost)
        }
        
        connectionFailurePhysics?.triggerCascadeFailures(at: positions)
    }
    
    private func updateArcStatusForNode(_ nodeId: String, status: Visualization.ArcSystem.ConnectionStatus) {
        // Update all arcs connected to this node
        networkService.connections.forEach { conn in
            if conn.sourceId == nodeId || conn.targetId == nodeId {
                let arcProperties = Visualization.ArcSystem.ArcProperties(
                    id: conn.id,
                    sourceId: conn.sourceId,
                    targetId: conn.targetId,
                    weight: conn.weight,
                    status: status
                )
                arcSystem?.updateArc(id: conn.id, properties: arcProperties)
            }
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updatePerformanceMetrics()
        }
    }
    
    private func updatePerformanceMetrics() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime > 0 {
            frameRate = 1.0 / deltaTime
        }
        
        lastFrameTime = currentTime
        
        // Update performance state
        state.currentFPS = frameRate
        state.isPerformanceOptimal = frameRate >= 30.0
        
        // Optimize if performance is poor
        if frameRate < 30.0 {
            optimizePerformance()
        }
    }
    
    private func optimizePerformance() {
        // Reduce particle count
        connectionFailurePhysics?.setMaxParticles(50)
        
        // Update LOD
        lodManager?.aggressiveLOD()
        
        // Reduce arc detail
        arcSystem?.updateLOD(cameraPosition: cameraNode?.position ?? SCNVector3Zero)
    }
    
    // MARK: - Enhanced Scene Setup
    
    private func setupScene() {
        scene.background.contents = createNightSkyGradient()
        setupCamera()
        setupLighting()
        setupGlobe()
    }
    
    private func setupCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 100
        
        // Enhanced camera settings for night mode
        camera.wantsHDR = true
        camera.bloomIntensity = isNightMode ? 1.5 : 1.0
        camera.bloomBlurRadius = 10.0
        camera.bloomThreshold = isNightMode ? 0.3 : 0.5
        
        cameraNode = SCNNode()
        cameraNode?.camera = camera
        cameraNode?.position = SCNVector3(0, 0, 3)
        
        scene.rootNode.addChildNode(cameraNode!)
    }
    
    private func setupGlobe() {
        let sphere = SCNSphere(radius: CGFloat(Math.GeospatialMath.earthRadius))
        sphere.segmentCount = 96 // High resolution for morphing
        
        let material = SCNMaterial()
        material.diffuse.contents = UniversalColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 0.8)
        material.lightingModel = .physicallyBased
        material.shaderModifiers = [
            .geometry: Core.MorphShader.geometryModifier,
            .surface: Core.MorphShader.surfaceModifier
        ]
        
        // Initialize uniforms
        material.setValue(Float(0.0), forKey: "u_mix")
        material.setValue(Float(Math.GeospatialMath.earthRadius), forKey: "u_radius")
        
        globeNode = SCNNode(geometry: sphere)
        globeNode?.name = "MainGlobe"
        scene.rootNode.addChildNode(globeNode!)
    }
    
    private func setupLighting() {
        setupNightModeLighting(isNightMode)
    }
    
    // MARK: - Stage 5 Camera System Enhancements
    
    /// Auto-fits camera to display specified nodes with intelligent framing
    /// - Parameters:
    ///   - nodeIds: Array of node identifiers to fit in view
    ///   - mode: Current view mode (3D, 2D, or hybrid)
    ///   - completion: Optional completion handler
    public func autoFitCameraToNodes(
        _ nodeIds: [String],
        mode: ApplicationState.ViewMode = .globe3D,
        completion: (() -> Void)? = nil
    ) {
        let viewMode = convertToViewMode(mode)
        cameraTransitionManager?.autoFitToNodes(nodeIds, mode: viewMode, completion: completion)
    }
    
    /// Smart focus using weighted algorithms
    /// - Parameters:
    ///   - nodeIds: Nodes to focus on
    ///   - strategy: Focus strategy (connection density, critical path, etc.)
    ///   - completion: Optional completion handler
    public func smartFocusCamera(
        _ nodeIds: [String],
        strategy: FocusStrategy = .default,
        completion: (() -> Void)? = nil
    ) {
        cameraTransitionManager?.smartFocus(nodeIds, strategy: strategy, completion: completion)
    }
    
    /// Updates camera system for performance optimization
    /// - Parameter deltaTime: Time since last frame
    public func updateCameraSystem(deltaTime: TimeInterval) {
        cameraTransitionManager?.update(deltaTime: deltaTime)
    }
    
    /// Invalidates cached camera bounds data
    public func invalidateCameraCache() {
        cameraTransitionManager?.invalidateCache()
    }
    
    // MARK: - Visual Updates
    
    public func focusCamera(on node: NetworkService.Node) {
        cameraTransitionManager?.focusOnPoints([(node.lat, node.lon)])
    }
    
    public func resetCamera() {
        cameraTransitionManager?.resetView()
    }
    
    private func handleViewModeChange(_ mode: ApplicationState.ViewMode) {
        let mixTarget: Float = (mode == .globe3D) ? 0.0 : 1.0
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        state.mixFactor = mixTarget
        globeNode?.geometry?.firstMaterial?.setValue(mixTarget, forKey: "u_mix")
        
        SCNTransaction.commit()
    }
    
    private func addCityLabel(idPath: String, lat: Double, lon: Double) {
        let pos = Math.GeospatialMath.latLonToCartesian(lat: lat, lon: lon)
        let text = SCNText(string: idPath, extrusionDepth: 0.01)
        text.firstMaterial?.diffuse.contents = isNightMode ? UniversalColor.white : UniversalColor.black
        text.font = UniversalFont.systemFont(ofSize: 0.1)
        
        let labelNode = SCNNode(geometry: text)
        labelNode.position = pos
        labelNode.scale = SCNVector3(0.5, 0.5, 0.5)
        
        // Ensure labels face camera (billboarding approach)
        labelNode.constraints = [SCNBillboardConstraint()]
        
        scene.rootNode.addChildNode(labelNode)
    }
    
    // MARK: - Public Interface
    
    public func triggerFailure(at nodeId: String) {
        triggerConnectionFailure(at: nodeId)
    }
    
    public func toggleNightMode() {
        updateForNightMode(!isNightMode)
    }
    
    public func cleanup() {
        arcSystem?.clearArcs()
        connectionFailurePhysics?.clearAll()
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        cancellables.removeAll()
        performanceTimer?.invalidate()
        
        // Stage 5: Cleanup camera system
        cameraTransitionManager = nil
        autoFitCameraSystem = nil
    }
    
    // MARK: - Helper Methods
    
    private func convertToViewMode(_ mode: ApplicationState.ViewMode) -> ViewMode {
        switch mode {
        case .globe3D:
            return .globe3D
        case .globe2D:
            return .globe2D
        case .hybrid:
            return .hybrid
        }
    }
}
