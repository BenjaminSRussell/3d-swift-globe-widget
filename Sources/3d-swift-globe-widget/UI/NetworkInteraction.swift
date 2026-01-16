import Foundation
import SceneKit
import Combine

/// Stage 3: Network interaction system
/// Handles user interactions with network topology and data flow
@MainActor
@available(iOS 15.0, macOS 12.0, *)
public class NetworkInteraction: ObservableObject {
    
    // MARK: - Properties
    private let scene: SCNScene
    private let cameraNode: SCNNode
    @Published public var interactionMode: InteractionMode = .selection
    @Published public var selectedNodes: Set<String> = []
    @Published public var selectedConnections: Set<String> = []
    @Published public var hoveredNode: String?
    @Published public var isDragging: Bool = false
    
    // Gesture handling
    private var lastPanPoint: CGPoint?
    private var selectionStartPoint: CGPoint?
    
    // MARK: - Initialization
    public init(scene: SCNScene, cameraNode: SCNNode) {
        self.scene = scene
        self.cameraNode = cameraNode
    }
    
    // MARK: - Public Methods
    public func setInteractionMode(_ mode: InteractionMode) {
        interactionMode = mode
        clearSelection()
    }
    
    public func handleTap(at point: CGPoint, in view: SCNView) -> Bool {
        switch interactionMode {
        case .selection:
            return handleSelectionTap(at: point, in: view)
        case .creation:
            return handleCreationTap(at: point, in: view)
        case .deletion:
            return handleDeletionTap(at: point, in: view)
        case .inspection:
            return handleInspectionTap(at: point, in: view)
        }
    }
    
    public func handlePan(_ gesture: UIPanGestureRecognizer, in view: SCNView) {
        switch gesture.state {
        case .began:
            lastPanPoint = gesture.location(in: view)
            selectionStartPoint = gesture.location(in: view)
        case .changed:
            handlePanChange(gesture, in: view)
        case .ended:
            handlePanEnd(gesture, in: view)
        default:
            break
        }
    }
    
    public func clearSelection() {
        selectedNodes.removeAll()
        selectedConnections.removeAll()
        hoveredNode = nil
    }
    
    public func selectNode(_ nodeId: String) {
        selectedNodes.insert(nodeId)
    }
    
    public func deselectNode(_ nodeId: String) {
        selectedNodes.remove(nodeId)
    }
    
    public func selectConnection(_ connectionId: String) {
        selectedConnections.insert(connectionId)
    }
    
    public func deselectConnection(_ connectionId: String) {
        selectedConnections.remove(connectionId)
    }
    
    // MARK: - Private Methods
    private func handleSelectionTap(at point: CGPoint, in view: SCNView) -> Bool {
        let hitResults = view.hitTest(point, options: [:])
        
        for result in hitResults {
            if let nodeName = result.node.name {
                if nodeName.starts(with: "node_") {
                    let nodeId = String(nodeName.dropFirst(5))
                    toggleNodeSelection(nodeId)
                    return true
                } else if nodeName.starts(with: "connection_") {
                    let connectionId = String(nodeName.dropFirst(11))
                    toggleConnectionSelection(connectionId)
                    return true
                }
            }
        }
        
        // Clicked on empty space - clear selection
        clearSelection()
        return false
    }
    
    private func handleCreationTap(at point: CGPoint, in view: SCNView) -> Bool {
        // TODO: Implement node/connection creation
        return false
    }
    
    private func handleDeletionTap(at point: CGPoint, in view: SCNView) -> Bool {
        // TODO: Implement node/connection deletion
        return false
    }
    
    private func handleInspectionTap(at point: CGPoint, in view: SCNView) -> Bool {
        // TODO: Implement node/connection inspection
        return false
    }
    
    private func handlePanChange(_ gesture: UIPanGestureRecognizer, in view: SCNView) {
        guard let startPoint = lastPanPoint else { return }
        
        let currentPoint = gesture.location(in: view)
        let translation = CGPoint(
            x: currentPoint.x - startPoint.x,
            y: currentPoint.y - startPoint.y
        )
        
        switch interactionMode {
        case .selection:
            handleSelectionPan(translation: translation, in: view)
        case .creation:
            handleCreationPan(translation: translation, in: view)
        case .deletion:
            handleDeletionPan(translation: translation, in: view)
        case .inspection:
            handleInspectionPan(translation: translation, in: view)
        }
        
        lastPanPoint = currentPoint
    }
    
    private func handlePanEnd(_ gesture: UIPanGestureRecognizer, in view: SCNView) {
        isDragging = false
        lastPanPoint = nil
        selectionStartPoint = nil
    }
    
    private func handleSelectionPan(translation: CGPoint, in view: SCNView) {
        // Handle selection box drag
        if let startPoint = selectionStartPoint {
            isDragging = true
            updateSelectionBox(from: startPoint, to: translation, in: view)
        }
    }
    
    private func handleCreationPan(translation: CGPoint, in view: SCNView) {
        // TODO: Handle connection creation drag
    }
    
    private func handleDeletionPan(translation: CGPoint, in view: SCNView) {
        // TODO: Handle deletion gesture
    }
    
    private func handleInspectionPan(translation: CGPoint, in view: SCNView) {
        // TODO: Handle inspection pan
    }
    
    private func toggleNodeSelection(_ nodeId: String) {
        if selectedNodes.contains(nodeId) {
            selectedNodes.remove(nodeId)
        } else {
            selectedNodes.insert(nodeId)
        }
    }
    
    private func toggleConnectionSelection(_ connectionId: String) {
        if selectedConnections.contains(connectionId) {
            selectedConnections.remove(connectionId)
        } else {
            selectedConnections.insert(connectionId)
        }
    }
    
    private func updateSelectionBox(from start: CGPoint, to translation: CGPoint, in view: SCNView) {
        // TODO: Implement visual selection box
    }
    
    // MARK: - Supporting Types
    public enum InteractionMode {
        case selection    // Select nodes and connections
        case creation    // Create new nodes/connections
        case deletion    // Delete nodes/connections
        case inspection   // Inspect node/connection details
        
        var description: String {
            switch self {
            case .selection: return "Selection"
            case .creation: return "Creation"
            case .deletion: return "Deletion"
            case .inspection: return "Inspection"
            }
        }
        
        var icon: String {
            switch self {
            case .selection: return "cursorarrow"
            case .creation: return "plus"
            case .deletion: return "trash"
            case .inspection: return "info.circle"
            }
        }
    }
}
