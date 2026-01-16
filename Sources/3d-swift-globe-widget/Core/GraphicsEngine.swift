import SceneKit
import SwiftUI
import Metal
import Combine

/// High-performance graphics engine for 3D globe visualization
/// Orchestrates modular components for math, physics, and visualization
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class GraphicsEngine: ObservableObject {
    
    // MARK: - Modules
    @Published public var state = ApplicationState()
    public let networkService = NetworkService()
    
    private var arcSystem: ArcSystem?
    private var particleSystem: ParticleSystem?
    private var burstController: BurstController?
    private var cameraTransitionManager: CameraTransitionManager?
    private var lodManager: LODManager?
    
    // MARK: - Scene Properties
    @Published public var scene = SCNScene()
    @Published public var frameRate: Double = 60.0
    @Published public var drawCallCount: Int = 0
    
    private var cameraNode: SCNNode?
    private var globeNode: SCNNode?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init() {
        setupScene()
        initializeModules()
        setupBindings()
        
        // Initial data load
        networkService.loadData()
    }
    
    private func initializeModules() {
        self.arcSystem = ArcSystem(scene: scene)
        self.particleSystem = ParticleSystem(scene: scene)
        self.burstController = BurstController(particleSystem: particleSystem!)
        
        if let cam = cameraNode {
            self.cameraTransitionManager = CameraTransitionManager(cameraNode: cam)
            self.lodManager = LODManager(cameraNode: cam)
        }
    }
    
    private func setupBindings() {
        // Bind state changes to visual updates
        state.$viewMode
            .sink { [weak self] mode in
                self?.handleViewModeChange(mode)
            }
            .store(in: &cancellables)
            
        Timer.publish(every: 1.0/5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performLODUpdate()
            }
            .store(in: &cancellables)
    }
    
    /// External trigger for particle bursts at specific geospatial points
    public func triggerBurst(at position: SCNVector3, color: UniversalColor) {
        burstController?.triggerFailureBurst(at: position)
    }
    
    private func performLODUpdate() {
        guard let globe = globeNode else { return }
        lodManager?.updateLOD(for: globe)
        // Future: update arcs/nodes LOD
    }
    
    // MARK: - Scene Setup
    private func setupScene() {
        scene.background.contents = UniversalColor.black
        setupCamera()
        setupLighting()
        setupGlobe()
    }
    
    private func setupCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 100
        
        // Final Polish: High dynamic range and neon bloom
        camera.wantsHDR = true
        camera.bloomIntensity = 1.0
        camera.bloomBlurRadius = 10.0
        camera.bloomThreshold = 0.5
        
        cameraNode = SCNNode()
        cameraNode?.camera = camera
        cameraNode?.position = SCNVector3(0, 0, 3)
        
        scene.rootNode.addChildNode(cameraNode!)
    }
    
    private func setupGlobe() {
        let sphere = SCNSphere(radius: CGFloat(GeospatialMath.earthRadius))
        sphere.segmentCount = 96 // High resolution for morphing
        
        let material = SCNMaterial()
        material.diffuse.contents = UniversalColor.systemBlue.withAlphaComponent(0.8)
        material.lightingModel = .physicallyBased
        material.shaderModifiers = [
            .geometry: MorphShader.geometryModifier,
            .surface: MorphShader.surfaceModifier
        ]
        
        // Initialize uniforms
        material.setValue(Float(0.0), forKey: "u_mix")
        material.setValue(Float(GeospatialMath.earthRadius), forKey: "u_radius")
        
        globeNode = SCNNode(geometry: sphere)
        globeNode?.name = "MainGlobe"
        scene.rootNode.addChildNode(globeNode!)
    }
    
    private func setupLighting() {
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
    
    public func updateArcs(for connections: [NetworkService.Connection]) {
        arcSystem?.clearArcs()
        for conn in connections {
            guard let source = networkService.nodes.first(where: { $0.id == conn.sourceId }),
                  let target = networkService.nodes.first(where: { $0.id == conn.targetId }) else { continue }
            
            arcSystem?.createArc(id: conn.id, from: (source.lat, source.lon), to: (target.lat, target.lon))
            
            // Add labels for better verification
            addCityLabel(idPath: source.id, lat: source.lat, lon: source.lon)
            addCityLabel(idPath: target.id, lat: target.lat, lon: target.lon)
        }
    }
    
    private func addCityLabel(idPath: String, lat: Double, lon: Double) {
        let pos = GeospatialMath.latLonToCartesian(lat: lat, lon: lon)
        let text = SCNText(string: idPath, extrusionDepth: 0.01)
        text.firstMaterial?.diffuse.contents = UniversalColor.white
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
        guard let node = networkService.nodes.first(where: { $0.id == nodeId }) else { return }
        let pos = GeospatialMath.latLonToCartesian(lat: node.lat, lon: node.lon)
        burstController?.triggerFailureBurst(at: pos)
    }
    
    public func cleanup() {
        arcSystem?.clearArcs()
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        cancellables.removeAll()
    }
}
