#if canImport(MapKit) && canImport(SwiftUI) && os(macOS)
import SwiftUI
import MapKit
import AppKit

extension CLLocationCoordinate2D {
    init(_ c: GeoCoordinate) { self.init(latitude: c.latitude, longitude: c.longitude) }
}

// MARK: - Map System
public struct GlobeView: NSViewRepresentable {
    let dataset: GlobeDataset
    let configuration: Configuration
    @Binding var triggerAnimation: Bool
    /// Set to frame the camera (bookmark restore); reset to nil once applied
    @Binding var cameraRequest: CameraBookmark?
    /// Updated as the user moves the map (used for "Save current view")
    @Binding var currentCamera: CameraBookmark?
    @Binding var selectedNodeID: String?

    public init(
        dataset: GlobeDataset,
        configuration: Configuration,
        triggerAnimation: Binding<Bool>,
        cameraRequest: Binding<CameraBookmark?>,
        currentCamera: Binding<CameraBookmark?>,
        selectedNodeID: Binding<String?>
    ) {
        self.dataset = dataset
        self.configuration = configuration
        self._triggerAnimation = triggerAnimation
        self._cameraRequest = cameraRequest
        self._currentCamera = currentCamera
        self._selectedNodeID = selectedNodeID
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        configureMap(mapView)
        Self.apply(configuration.initialCamera(for: dataset), to: mapView, animated: false)
        context.coordinator.load(dataset, on: mapView)
        return mapView
    }

    public func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.loadedDataset != dataset {
            context.coordinator.load(dataset, on: nsView)
            Self.apply(configuration.initialCamera(for: dataset), to: nsView, animated: true)
        }

        if let request = cameraRequest {
            Self.apply(request, to: nsView, animated: true)
            Task { @MainActor in self.cameraRequest = nil }
        }

        if triggerAnimation {
            for arc in dataset.arcs {
                ArcVisualizer.animateArc(
                    from: CLLocationCoordinate2D(arc.from.coordinate),
                    to: CLLocationCoordinate2D(arc.to.coordinate),
                    duration: configuration.arcs.animationSeconds,
                    on: nsView
                )
            }
            Task { @MainActor in self.triggerAnimation = false }
        }
    }

    static func apply(_ bookmark: CameraBookmark, to mapView: MKMapView, animated: Bool) {
        let camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(bookmark.center),
            fromDistance: bookmark.distanceMeters,
            pitch: CGFloat(bookmark.pitch),
            heading: bookmark.heading
        )
        mapView.setCamera(camera, animated: animated)
    }

    private func configureMap(_ mapView: MKMapView) {
        mapView.mapType = .satelliteFlyover
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true

        mapView.showsZoomControls = true
        mapView.showsCompass = true
        mapView.showsScale = true
    }

    public class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GlobeView
        var loadedDataset: GlobeDataset?

        init(_ parent: GlobeView) {
            self.parent = parent
        }

        @MainActor
        func load(_ dataset: GlobeDataset, on mapView: MKMapView) {
            mapView.removeAnnotations(mapView.annotations)
            ServerLightsVisualizer.distributeServerLights(
                nodes: dataset.nodes,
                jitterDegrees: parent.configuration.lights.jitterDegrees,
                on: mapView
            )
            loadedDataset = dataset
        }

        @MainActor
        public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let cam = mapView.camera
            let snapshot = CameraBookmark(
                name: "Current",
                center: GeoCoordinate(latitude: cam.centerCoordinate.latitude, longitude: cam.centerCoordinate.longitude),
                distanceMeters: cam.centerCoordinateDistance,
                pitch: Double(cam.pitch),
                heading: cam.heading
            )
            let parent = self.parent
            Task { @MainActor in parent.currentCamera = snapshot }
        }

        @MainActor
        public func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let node = annotation as? NodeAnnotation else { return }
            let parent = self.parent
            let id = node.nodeID
            Task { @MainActor in parent.selectedNodeID = id }
        }

        @MainActor
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                // "White Hot" Core with Blue Glow (Managed by Shadow)
                renderer.strokeColor = NSColor.white
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        @MainActor
        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is NodeAnnotation {
                let identifier = "Node"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? Self.dotView(annotation: annotation, identifier: identifier, size: 8, glow: 6, alpha: 0.9)
                view.annotation = annotation
                view.canShowCallout = false
                return view
            }

            // Handle "ServerLight" - The tiny static server nodes
            if annotation.title == ServerLightsVisualizer.lightTitle {
                let identifier = "ServerLight"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? Self.dotView(annotation: annotation, identifier: identifier, size: 4, glow: 4, alpha: 0.8)
                view.annotation = annotation
                return view
            }

            // Handle "Packet" - The moving data packet
            let identifier = "Packet"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? Self.dotView(annotation: annotation, identifier: identifier, size: 12, glow: 10, alpha: 1.0)
            view.annotation = annotation
            return view
        }

        @MainActor
        static func dotView(annotation: MKAnnotation, identifier: String, size: CGFloat, glow: CGFloat, alpha: CGFloat) -> MKAnnotationView {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = false
            view.wantsLayer = true
            view.layer?.masksToBounds = false

            let dot = NSView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = NSColor.white.cgColor
            dot.layer?.cornerRadius = size / 2
            // Electric blue glow
            dot.layer?.shadowColor = NSColor(calibratedRed: 0.0, green: 0.55, blue: 1.0, alpha: alpha).cgColor
            dot.layer?.shadowRadius = glow
            dot.layer?.shadowOpacity = Float(alpha)
            dot.layer?.shadowOffset = .zero

            view.frame = dot.frame
            view.addSubview(dot)
            return view
        }
    }
}
#endif
