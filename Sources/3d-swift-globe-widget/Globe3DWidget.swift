import SwiftUI
import SceneKit

public struct Globe3DWidget: View {
    @State private var scene = SCNScene()
    @State private var isRotating = true
    
    public init() {}
    
    public var body: some View {
        SceneView(
            scene: scene,
            options: [.allowsCameraControl, .autoenablesDefaultLighting]
        )
        .onAppear {
            setupGlobe()
            startRotation()
        }
    }
    
    private func setupGlobe() {
        // Create a sphere geometry for the globe
        let globeGeometry = SCNSphere(radius: 1.0)
        
        // Create a material with a basic Earth-like appearance
        let material = SCNMaterial()
        material.diffuse.contents = createEarthTexture()
        material.specular.contents = UIColor.white
        material.shininess = 0.1
        globeGeometry.materials = [material]
        
        // Create the globe node
        let globeNode = SCNNode(geometry: globeGeometry)
        globeNode.name = "globe"
        
        // Add the globe to the scene
        scene.rootNode.addChildNode(globeNode)
        
        // Setup camera
        setupCamera()
        
        // Add some ambient lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(white: 0.3, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)
        
        // Add directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .omni
        directionalLight.light!.color = UIColor(white: 0.8, alpha: 1.0)
        directionalLight.position = SCNVector3(0, 50, 50)
        scene.rootNode.addChildNode(directionalLight)
    }
    
    private func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 3)
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func createEarthTexture() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create a simple Earth-like texture
            let cgContext = context.cgContext
            
            // Ocean background (blue)
            cgContext.setFillColor(UIColor.systemBlue.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Simple continent shapes (green)
            cgContext.setFillColor(UIColor.systemGreen.cgColor)
            
            // Africa/Europe
            cgContext.fillEllipse(in: CGRect(x: 200, y: 80, width: 80, height: 100))
            
            // Americas
            cgContext.fillEllipse(in: CGRect(x: 80, y: 60, width: 60, height: 120))
            
            // Asia
            cgContext.fillEllipse(in: CGRect(x: 300, y: 70, width: 120, height: 80))
            
            // Australia
            cgContext.fillEllipse(in: CGRect(x: 350, y: 140, width: 60, height: 40))
        }
    }
    
    private func startRotation() {
        guard isRotating else { return }
        
        let rotationAction = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 20)
        let repeatAction = SCNAction.repeatForever(rotationAction)
        
        scene.rootNode.childNode(withName: "globe", recursively: true)?.runAction(repeatAction)
    }
}

// MARK: - Interactive Features
public extension Globe3DWidget {
    func stopRotation() -> Globe3DWidget {
        var view = self
        view.isRotating = false
        return view
    }
    
    func startRotation() -> Globe3DWidget {
        var view = self
        view.isRotating = true
        return view
    }
}

// MARK: - Location Support
public struct GeoLocation {
    public let latitude: Double
    public let longitude: Double
    public let name: String?
    
    public init(latitude: Double, longitude: Double, name: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
    }
}

public extension Globe3DWidget {
    func addLocationPin(at location: GeoLocation) -> Globe3DWidget {
        var view = self
        // Implementation for adding location pins would go here
        return view
    }
}
