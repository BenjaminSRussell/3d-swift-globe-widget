import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Universal color system for cross-platform compatibility
/// Provides consistent color definitions across iOS and macOS
@available(iOS 15.0, macOS 12.0, *)
public struct UniversalColor {
    
    // MARK: - Platform-specific color type
    #if os(iOS)
    public typealias PlatformColor = UIColor
    #else
    public typealias PlatformColor = NSColor
    #endif
    
    // MARK: - Properties
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
    
    // MARK: - Initialization
    
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(white: CGFloat, alpha: CGFloat = 1.0) {
        self.red = white
        self.green = white
        self.blue = white
        self.alpha = alpha
    }
    
    // MARK: - Static Colors
    
    public static let red = UniversalColor(red: 1.0, green: 0.0, blue: 0.0)
    public static let green = UniversalColor(red: 0.0, green: 1.0, blue: 0.0)
    public static let blue = UniversalColor(red: 0.0, green: 0.0, blue: 1.0)
    public static let cyan = UniversalColor(red: 0.0, green: 1.0, blue: 1.0)
    public static let magenta = UniversalColor(red: 1.0, green: 0.0, blue: 1.0)
    public static let yellow = UniversalColor(red: 1.0, green: 1.0, blue: 0.0)
    public static let black = UniversalColor(red: 0.0, green: 0.0, blue: 0.0)
    public static let white = UniversalColor(red: 1.0, green: 1.0, blue: 1.0)
    public static let gray = UniversalColor(red: 0.5, green: 0.5, blue: 0.5)
    public static let clear = UniversalColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    
    // MARK: - System Colors
    
    #if os(iOS)
    public static var systemBlue: UniversalColor {
        UniversalColor(uiColor: UIColor.systemBlue)
    }
    
    public static var systemGreen: UniversalColor {
        UniversalColor(uiColor: UIColor.systemGreen)
    }
    
    public static var systemRed: UniversalColor {
        UniversalColor(uiColor: UIColor.systemRed)
    }
    
    public static var systemYellow: UniversalColor {
        UniversalColor(uiColor: UIColor.systemYellow)
    }
    
    public static var systemOrange: UniversalColor {
        UniversalColor(uiColor: UIColor.systemOrange)
    }
    
    public static var systemPurple: UniversalColor {
        UniversalColor(uiColor: UIColor.systemPurple)
    }
    
    public static var systemPink: UniversalColor {
        UniversalColor(uiColor: UIColor.systemPink)
    }
    
    public static var systemTeal: UniversalColor {
        UniversalColor(uiColor: UIColor.systemTeal)
    }
    
    public static var systemIndigo: UniversalColor {
        UniversalColor(uiColor: UIColor.systemIndigo)
    }
    #else
    public static var systemBlue: UniversalColor {
        UniversalColor(nsColor: NSColor.systemBlue)
    }
    
    public static var systemGreen: UniversalColor {
        UniversalColor(nsColor: NSColor.systemGreen)
    }
    
    public static var systemRed: UniversalColor {
        UniversalColor(nsColor: NSColor.systemRed)
    }
    
    public static var systemYellow: UniversalColor {
        UniversalColor(nsColor: NSColor.systemYellow)
    }
    
    public static var systemOrange: UniversalColor {
        UniversalColor(nsColor: NSColor.systemOrange)
    }
    
    public static var systemPurple: UniversalColor {
        UniversalColor(nsColor: NSColor.systemPurple)
    }
    
    public static var systemPink: UniversalColor {
        UniversalColor(nsColor: NSColor.systemPink)
    }
    
    public static var systemTeal: UniversalColor {
        UniversalColor(nsColor: NSColor.systemTeal)
    }
    
    public static var systemIndigo: UniversalColor {
        UniversalColor(nsColor: NSColor.systemIndigo)
    }
    #endif
    
    // MARK: - Platform-specific Initializers
    
    #if os(iOS)
    public init(uiColor: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = r
        self.green = g
        self.blue = b
        self.alpha = a
    }
    
    public var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #else
    public init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        
        self.red = color.redComponent
        self.green = color.greenComponent
        self.blue = color.blueComponent
        self.alpha = color.alphaComponent
    }
    
    public var nsColor: NSColor {
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
    
    // MARK: - Conversion Methods
    
    public var cgColor: CGColor {
        #if os(iOS)
        return uiColor.cgColor
        #else
        return nsColor.cgColor
        #endif
    }
    
    public var color: Color {
        return Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    }
    
    // MARK: - Utility Methods
    
    public func withAlphaComponent(_ alpha: CGFloat) -> UniversalColor {
        return UniversalColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    public func blended(with color: UniversalColor, fraction: CGFloat) -> UniversalColor {
        let newRed = red + (color.red - red) * fraction
        let newGreen = green + (color.green - green) * fraction
        let newBlue = blue + (color.blue - blue) * fraction
        let newAlpha = alpha + (color.alpha - alpha) * fraction
        
        return UniversalColor(red: newRed, green: newGreen, blue: newBlue, alpha: newAlpha)
    }
    
    // MARK: - Image Creation
    
    public func createImage(size: CGSize) -> PlatformImage {
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.setFillColor(cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
        #else
        let image = NSImage(size: size)
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.setFillColor(cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
        #endif
    }
}

// MARK: - Platform Image Type

#if os(iOS)
public typealias PlatformImage = UIImage
#else
public typealias PlatformImage = NSImage
#endif

// MARK: - Universal Font

@available(iOS 15.0, macOS 12.0, *)
public struct UniversalFont {
    
    #if os(iOS)
    public static func systemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func boldSystemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont.boldSystemFont(ofSize: size)
    }
    
    public static func italicSystemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont.italicSystemFont(ofSize: size)
    }
    #else
    public static func systemFont(ofSize size: CGFloat) -> NSFont {
        return NSFont.systemFont(ofSize: size)
    }
    
    public static func boldSystemFont(ofSize size: CGFloat) -> NSFont {
        return NSFont.boldSystemFont(ofSize: size)
    }
    
    public static func italicSystemFont(ofSize size: CGFloat) -> NSFont {
        return NSFont.systemFont(ofSize: size, traits: [.italic])
    }
    #endif
}
