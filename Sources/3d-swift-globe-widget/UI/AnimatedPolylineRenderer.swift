import MapKit

/// Renders a polyline with an animated dash phase to simulate data flow
@available(iOS 15.0, macOS 12.0, *)
class AnimatedPolylineRenderer: MKPolylineRenderer, @unchecked Sendable {
    
    private var timer: Timer?
    
    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)
        startAnimation()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func startAnimation() {
        // Invalidate existing timer
        timer?.invalidate()
        
        // Schedule a timer to update the dash phase
        // Note: For smoother 60fps animation, a CADisplayLink (iOS) or CVDisplayLink (macOS) is better,
        // but Timer is simpler for a cross-platform demo and sufficient for "Marching Ants".
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Shift phase
            self.lineDashPhase -= 2 // Negative moves "forward" along the line usually
            self.setNeedsDisplay()
        }
    }
}
