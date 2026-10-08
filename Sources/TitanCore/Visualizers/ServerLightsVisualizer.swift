#if canImport(MapKit)
import MapKit
import Foundation

/// Annotation for a dataset node (selectable; opens NodeDetailView)
public final class NodeAnnotation: MKPointAnnotation {
    public let nodeID: String

    public init(node: GlobeNode) {
        self.nodeID = node.id
        super.init()
        self.coordinate = CLLocationCoordinate2D(latitude: node.coordinate.latitude, longitude: node.coordinate.longitude)
        self.title = node.name
    }
}

// MARK: - Visualizer System
@MainActor
public class ServerLightsVisualizer {
    /// Title used by GlobeView's renderer to style the tiny static lights
    public static let lightTitle = "ServerLight"

    /// Scatter `intensity` lights around each node plus one selectable hub annotation per node.
    public static func distributeServerLights(nodes: [GlobeNode], jitterDegrees: Double, on mapView: MKMapView) {
        var annotations: [MKAnnotation] = []

        for node in nodes {
            annotations.append(NodeAnnotation(node: node))
            for _ in 0..<max(0, node.intensity) {
                let light = MKPointAnnotation()
                // Randomize position slightly to create a "cluster" effect
                let deltaLat = jitterDegrees > 0 ? Double.random(in: -jitterDegrees...jitterDegrees) : 0
                let deltaLon = jitterDegrees > 0 ? Double.random(in: -jitterDegrees...jitterDegrees) : 0
                light.coordinate = CLLocationCoordinate2D(
                    latitude: max(-90, min(90, node.coordinate.latitude + deltaLat)),
                    longitude: node.coordinate.longitude + deltaLon
                )
                light.title = lightTitle
                annotations.append(light)
            }
        }

        mapView.addAnnotations(annotations)
    }
}
#endif
