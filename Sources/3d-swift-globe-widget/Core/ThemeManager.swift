import SwiftUI

/// Manages the visual appearance of the Globe Widget
@available(iOS 15.0, macOS 12.0, *)
public class ThemeManager: ObservableObject {
    
    public enum ThemeStyle {
        case cyber
        case standard
        case minimal
    }
    
    @Published public var currentTheme: ThemeStyle = .cyber
    
    public var accentColor: Color {
        switch currentTheme {
        case .cyber: return .cyan
        case .standard: return .blue
        case .minimal: return .primary
        }
    }
    
    public var secondaryColor: Color {
        switch currentTheme {
        case .cyber: return .purple
        case .standard: return .orange
        case .minimal: return .gray
        }
    }
    
    // For MapKit Use
    public var polylineColor: UniversalColor {
        switch currentTheme {
        case .cyber: return .cyan
        case .standard: return .blue
        case .minimal: return .black
        }
    }
    
    public var secondaryUniversalColor: UniversalColor {
        switch currentTheme {
        case .cyber: return .purple
        case .standard: return .orange
        case .minimal: return .gray
        }
    }
    
    public init() {}
    
    public func toggleTheme() {
        switch currentTheme {
        case .cyber: currentTheme = .standard
        case .standard: currentTheme = .minimal
        case .minimal: currentTheme = .cyber
        }
    }
}
