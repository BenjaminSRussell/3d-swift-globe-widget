import SwiftUI
import SceneKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Combine
import MapKit

#if canImport(UIKit)
import UIKit
typealias ViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
typealias ViewRepresentable = NSViewRepresentable
#endif

@available(iOS 15.0, macOS 12.0, *)
@available(iOS 15.0, macOS 12.0, *)
public struct MapKitGlobeView: ViewRepresentable {
    
    @ObservedObject var viewModel: GlobeViewModel
    
    public init(viewModel: GlobeViewModel) {
        self.viewModel = viewModel
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    #if canImport(AppKit)
    public func makeNSView(context: Context) -> MKMapView {
        let mapView = createMapView(context: context)
        return mapView
    }
    
    public func updateNSView(_ nsView: MKMapView, context: Context) {
        updateMapView(nsView, context: context)
    }
    #else
    public func makeUIView(context: Context) -> MKMapView {
        let mapView = createMapView(context: context)
        return mapView
    }
    
    public func updateUIView(_ uiView: MKMapView, context: Context) {
        updateMapView(uiView, context: context)
    }
    #endif
    
    private func createMapView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        mapView.mapType = .satelliteFlyover
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        
        // Register custom annotations
        mapView.register(NetworkAnnotationView.self, forAnnotationViewWithReuseIdentifier: NetworkAnnotationView.reuseID)
        mapView.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: ClusterAnnotationView.reuseID)
        
        let camera = MKMapCamera(lookingAtCenter: CLLocationCoordinate2D(latitude: 38.0, longitude: -95.0), fromDistance: 10_000_000, pitch: 0, heading: 0)
        mapView.camera = camera
        
        return mapView
    }
    
    private func updateMapView(_ mapView: MKMapView, context: Context) {
        // 1. Camera Updates
        if let targetId = viewModel.cameraTarget,
           let node = viewModel.nodes.first(where: { $0.id == targetId }) {
            
            let coords = CLLocationCoordinate2D(latitude: node.lat, longitude: node.lon)
            let camera = MKMapCamera(lookingAtCenter: coords, fromDistance: 2_000_000, pitch: 60, heading: 0)
            mapView.setCamera(camera, animated: true)
            
            // Allow VM to reset trigger if needed, or just let it stay
        }
        
        // 2. Data Updates
        if mapView.annotations.count != viewModel.nodes.count || mapView.overlays.count != viewModel.connections.count {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
            
            for conn in viewModel.connections {
                guard let source = viewModel.nodes.first(where: { $0.id == conn.sourceId }),
                      let target = viewModel.nodes.first(where: { $0.id == conn.targetId }) else { continue }
                
                let c1 = CLLocationCoordinate2D(latitude: source.lat, longitude: source.lon)
                let c2 = CLLocationCoordinate2D(latitude: target.lat, longitude: target.lon)
                var coordinates = [c1, c2]
                let geodesic = MKGeodesicPolyline(coordinates: &coordinates, count: 2)
                mapView.addOverlay(geodesic)
            }
            
            for node in viewModel.nodes {
                // Annotations
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: node.lat, longitude: node.lon)
                annotation.title = node.id
                annotation.subtitle = (node.status == .error) ? "error" : "active"
                mapView.addAnnotation(annotation)
                
                // Heatmap Overlays (only if load > 0.3)
                if node.load > 0.3 {
                    let radius = node.load * 500_000 // Scale radius by load (max ~500km)
                    let circle = MKCircle(center: annotation.coordinate, radius: radius)
                    mapView.addOverlay(circle)
                }
            }
        }
        
        // Force refresh overlays if theme changed (crude but effective)
        // In a real app we'd iterate and update renderers
    }
    
    // MARK: - Coordinator
    public class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitGlobeView
        
        init(_ parent: MapKitGlobeView) {
            self.parent = parent
        }
        
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                // Heatmap logic: Fill color based on load (title hack or just unified color)
                // Simpler: Just use a standard "Load" color (Purple/Red) with alpha
                renderer.fillColor = parent.viewModel.themeManager.secondaryUniversalColor.withAlphaComponent(0.3)
                renderer.strokeColor = parent.viewModel.themeManager.secondaryUniversalColor.withAlphaComponent(0.6)
                renderer.lineWidth = 1
                return renderer
            }
            
            if let polyline = overlay as? MKPolyline {
                // Use the new animated renderer
                let renderer = AnimatedPolylineRenderer(polyline: polyline)
                renderer.strokeColor = parent.viewModel.themeManager.polylineColor
                renderer.lineWidth = 3
                renderer.lineDashPattern = [12, 8] // Wider gaps for clearer animation
                renderer.alpha = 0.9
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKClusterAnnotation {
                return mapView.dequeueReusableAnnotationView(withIdentifier: ClusterAnnotationView.reuseID, for: annotation) as? ClusterAnnotationView ?? ClusterAnnotationView(annotation: annotation, reuseIdentifier: ClusterAnnotationView.reuseID)
            }
            
            guard annotation is MKPointAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: NetworkAnnotationView.reuseID, for: annotation) as? NetworkAnnotationView ?? NetworkAnnotationView(annotation: annotation, reuseIdentifier: NetworkAnnotationView.reuseID)
            
            if annotation.subtitle == "error" {
                view.setStatus(.error)
            } else {
                view.setStatus(.active)
            }
            return view
        }
    }
}
