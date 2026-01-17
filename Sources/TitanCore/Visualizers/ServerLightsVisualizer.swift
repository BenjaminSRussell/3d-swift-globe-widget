import MapKit
import Foundation

// MARK: - Visualizer System
@MainActor
public class ServerLightsVisualizer {
    
    // Defines a major tech hub / server farm location
    struct ServerHub {
        let name: String
        let coordinate: CLLocationCoordinate2D
        let intensity: Int // Number of "lights" to spawn around this hub
    }
    
    public static func distributeServerLights(on mapView: MKMapView) {
        // Major Data Center Hubs (Approximated)
        let hubs = [
            ServerHub(name: "US-East (N. Virginia)", coordinate: CLLocationCoordinate2D(latitude: 39.0438, longitude: -77.4874), intensity: 20),
            ServerHub(name: "US-West (Oregon)", coordinate: CLLocationCoordinate2D(latitude: 45.8399, longitude: -119.7006), intensity: 15),
            ServerHub(name: "US-West (California)", coordinate: CLLocationCoordinate2D(latitude: 37.3382, longitude: -121.8863), intensity: 18),
            ServerHub(name: "EU-West (Ireland)", coordinate: CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603), intensity: 15),
            ServerHub(name: "EU-Central (Frankfurt)", coordinate: CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821), intensity: 16),
            ServerHub(name: "APAC (Tokyo)", coordinate: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503), intensity: 20),
            ServerHub(name: "APAC (Singapore)", coordinate: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198), intensity: 14),
            ServerHub(name: "AUS (Sydney)", coordinate: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093), intensity: 12),
            ServerHub(name: "SA (São Paulo)", coordinate: CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333), intensity: 10)
        ]
        
        var annotations: [MKAnnotation] = []
        
        for hub in hubs {
            for _ in 0..<hub.intensity {
                let light = MKPointAnnotation()
                // Randomize position slightly to create a "cluster" effect
                // Delta of 0.1 ~ 11km, keeping it tight like a city/campus
                let deltaLat = Double.random(in: -0.5...0.5) 
                let deltaLon = Double.random(in: -0.5...0.5)
                
                light.coordinate = CLLocationCoordinate2D(
                    latitude: hub.coordinate.latitude + deltaLat,
                    longitude: hub.coordinate.longitude + deltaLon
                )
                light.title = "ServerLight" // Identifier for the renderer
                annotations.append(light)
            }
        }
        
        mapView.addAnnotations(annotations)
    }
}
