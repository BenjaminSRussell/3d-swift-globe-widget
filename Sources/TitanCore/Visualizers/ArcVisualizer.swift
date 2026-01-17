import MapKit
import Foundation

// MARK: - Visualizer System
@MainActor
public class ArcVisualizer {
    public static func animateArc(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, on mapView: MKMapView) {
        // Create the "Dot" annotation
        let packet = MKPointAnnotation()
        packet.coordinate = start
        packet.title = "Data Packet"
        mapView.addAnnotation(packet)
        
        // Calculate Geodesic Path
        var coordinates = [start, end]
        let geodesic = MKGeodesicPolyline(coordinates: &coordinates, count: 2)
        
        // Extract points
        let pointCount = geodesic.pointCount
        let pointsPtr = geodesic.points()
        let points = Array(UnsafeBufferPointer(start: pointsPtr, count: pointCount))
        
        var currentTrailPolyline: MKPolyline?
        
        // Use Swift Concurrency Task for Animation Loop to avoid Sendable warnings
        Task {
            let duration: TimeInterval = 3.0
            let startTime = Date()
            var frameCount = 0
            
            // simple 60fps loop
            while true {
                let elapsed = Date().timeIntervalSince(startTime)
                var fraction = elapsed / duration
                
                if fraction >= 1.0 {
                    fraction = 1.0
                    packet.coordinate = points.last?.coordinate ?? end
                    
                    // Cleanup trail after delay
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    mapView.removeAnnotation(packet)
                    if let trail = currentTrailPolyline {
                        mapView.removeOverlay(trail)
                    }
                    return
                }
                
                // Interpolate
                let index = Int(fraction * Double(pointCount - 1))
                let safeIndex = min(max(index, 0), pointCount - 1)
                let mapPoint = points[safeIndex]
                packet.coordinate = mapPoint.coordinate
                
                // Update Trail
                // removing throttle for smoothness
                let activePoints = Array(points.prefix(safeIndex + 1))
                
                // VALIDATION: Polyline needs at least 2 points
                if activePoints.count > 1 {
                    if let oldTrail = currentTrailPolyline {
                        mapView.removeOverlay(oldTrail)
                    }
                    
                    currentTrailPolyline = MKPolyline(points: activePoints, count: activePoints.count)
                    if let newTrail = currentTrailPolyline {
                        mapView.addOverlay(newTrail)
                    }
                }
                
                frameCount += 1
                // Sleep for ~16ms (60 FPS for Dot)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}
