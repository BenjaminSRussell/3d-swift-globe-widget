import MapKit

@available(iOS 15.0, macOS 12.0, *)
class ClusterAnnotationView: MKAnnotationView {
    
    static let reuseID = "ClusterNode"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.displayPriority = .defaultHigh
        self.collisionMode = .circle
        setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        self.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        self.canShowCallout = true
        
        let count = (annotation as? MKClusterAnnotation)?.memberAnnotations.count ?? 0
        
        // Visual: A larger cyan ring with the count
        let circleLayer = CALayer()
        circleLayer.frame = self.bounds
        circleLayer.cornerRadius = 15
        circleLayer.backgroundColor = UniversalColor.cyan.withAlphaComponent(0.2).cgColor
        circleLayer.borderWidth = 2
        circleLayer.borderColor = UniversalColor.cyan.cgColor
        self.layer?.addSublayer(circleLayer)
        
        // Text Layer for Count
        let textLayer = CATextLayer()
        textLayer.string = "\(count)"
        textLayer.font = UniversalFont.boldSystemFont(ofSize: 12)
        textLayer.fontSize = 12
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: 0, y: 8, width: 30, height: 14)
        textLayer.contentsScale = 2.0 // Retina support
        textLayer.foregroundColor = UniversalColor.white.cgColor
        self.layer?.addSublayer(textLayer)
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        
        // Update count if it changed
        if let textLayer = self.layer?.sublayers?.compactMap({ $0 as? CATextLayer }).first {
            textLayer.string = "\(cluster.memberAnnotations.count)"
        }
    }
}
