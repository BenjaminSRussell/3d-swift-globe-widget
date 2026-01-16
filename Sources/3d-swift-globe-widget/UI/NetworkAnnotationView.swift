import MapKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Custom annotation view mimicking a data node with a pulse effect
@available(iOS 15.0, macOS 12.0, *)
class NetworkAnnotationView: MKAnnotationView {
    
    static let reuseID = "NetworkNode"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.clusteringIdentifier = "DetailsCluster" // Enables native clustering
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Core visual: A small bright circle
        self.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        self.canShowCallout = true
        
        let circleLayer = CALayer()
        circleLayer.frame = self.bounds
        circleLayer.cornerRadius = 8
        circleLayer.backgroundColor = UniversalColor.cyan.cgColor
        circleLayer.borderWidth = 2
        circleLayer.borderColor = UniversalColor.white.cgColor
        self.layer?.addSublayer(circleLayer)
        
        // Pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.5
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.5
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        circleLayer.add(pulseAnimation, forKey: "pulse")
        
        // Shadow/Glow
        self.layer?.shadowColor = UniversalColor.cyan.cgColor
        self.layer?.shadowRadius = 5
        self.layer?.shadowOpacity = 0.8
        self.layer?.shadowOffset = .zero
    }
    
    func setStatus(_ status: NetworkService.Node.Status) {
        if let circle = self.layer?.sublayers?.first {
            switch status {
            case .active:
                circle.backgroundColor = UniversalColor.cyan.cgColor
                self.layer?.shadowColor = UniversalColor.cyan.cgColor
            case .error:
                circle.backgroundColor = UniversalColor.red.cgColor
                self.layer?.shadowColor = UniversalColor.red.cgColor
            case .inactive:
                circle.backgroundColor = UniversalColor.gray.cgColor
                self.layer?.shadowColor = UniversalColor.clear.cgColor
            }
        }
    }
}
