import SwiftUI
import MapKit

#if os(macOS)
import AppKit
#endif

// MARK: - Map System
public struct GlobeView: NSViewRepresentable {
    // Communication Binding
    @Binding var triggerAnimation: Bool
    
    public init(triggerAnimation: Binding<Bool>) {
        self._triggerAnimation = triggerAnimation
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        configureMap(mapView)
        
        // Initialize the "Server Cluster" visualization layer
        DispatchQueue.main.async {
            ServerLightsVisualizer.distributeServerLights(on: mapView)
        }
        
        return mapView
    }
    
    public func updateNSView(_ nsView: MKMapView, context: Context) {
        if triggerAnimation {
            print("DEBUG: GlobeView received trigger. Animating now.")
            
            let nyc = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
            let la = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
            
            ArcVisualizer.animateArc(from: nyc, to: la, on: nsView)
            
            DispatchQueue.main.async {
                self.triggerAnimation = false
            }
        }
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
        
        let center = CLLocationCoordinate2D(latitude: 39.0, longitude: -96.0)
        let camera = MKMapCamera(lookingAtCenter: center, fromDistance: 8_000_000, pitch: 0, heading: 0)
        mapView.camera = camera
    }
    
    public class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GlobeView
        
        init(_ parent: GlobeView) {
            self.parent = parent
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
            // Handle "ServerLight" - The tiny static server nodes
            if annotation.title == "ServerLight" {
                let identifier = "ServerLight"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = false
                    
                    // Tiny, high-density dot style
                    let lightSize: CGFloat = 4
                    let dot = NSView(frame: CGRect(x: 0, y: 0, width: lightSize, height: lightSize))
                    dot.wantsLayer = true
                    dot.layer?.backgroundColor = NSColor.white.cgColor
                    dot.layer?.cornerRadius = lightSize / 2
                    
                    // Subtle blue glow for the "connected" look
                    dot.layer?.shadowColor = NSColor(calibratedRed: 0.0, green: 0.5, blue: 1.0, alpha: 0.8).cgColor
                    dot.layer?.shadowRadius = 4
                    dot.layer?.shadowOpacity = 0.8
                    dot.layer?.shadowOffset = .zero
                    
                    view?.frame = dot.frame
                    view?.addSubview(dot)
                } else {
                    view?.annotation = annotation
                }
                return view
            }
            
            // Handle "Packet" - The moving data packet
            // print("DEBUG: viewFor annotation called for \(annotation.title ?? "nil")")
            let identifier = "Packet"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = false
                
                // IMPORTANT: Ensure the annotation view itself handles layers
                view?.wantsLayer = true
                view?.layer?.masksToBounds = false
                
                let dotSize: CGFloat = 12 // Slightly smaller, more precise
                let dot = NSView(frame: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
                dot.wantsLayer = true
                dot.layer?.backgroundColor = NSColor.white.cgColor // White core
                dot.layer?.cornerRadius = dotSize / 2
                
                // Add a "Force Field" Glow Effect
                dot.layer?.shadowColor = NSColor(calibratedRed: 0.0, green: 0.6, blue: 1.0, alpha: 1.0).cgColor // Deep Electric Blue
                dot.layer?.shadowRadius = 10
                dot.layer?.shadowOpacity = 1.0
                dot.layer?.shadowOffset = .zero
                
                view?.frame = dot.frame
                view?.addSubview(dot)
            } else {
                view?.annotation = annotation
            }
            
            return view
        }
    }
}
