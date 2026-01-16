import Foundation
import Combine
import MapKit
import SwiftUI

/// Main ViewModel governing the application state (Phase 1)
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class GlobeViewModel: ObservableObject {
    
    // Dependencies
    public let themeManager = ThemeManager()
    private let networkService = NetworkService()
    
    // State
    @Published public var nodes: [NetworkService.Node] = []
    @Published public var connections: [NetworkService.Connection] = []
    @Published public var cameraTarget: String? = nil
    @Published public var selectedNode: NetworkService.Node? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
        networkService.loadData() // Initial data load
    }
    
    private func setupBindings() {
        // networkService is an ObservableObject, so we bind to its published properties
        networkService.$nodes
            .assign(to: \.nodes, on: self)
            .store(in: &cancellables)
            
        networkService.$connections
            .assign(to: \.connections, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    public func selectNode(_ id: String) {
        if let node = nodes.first(where: { $0.id == id }) {
            self.selectedNode = node
            self.cameraTarget = id
            print("GlobeViewModel: Selected \(id)")
        }
    }
    
    public func clearSelection() {
        self.selectedNode = nil
    }
    
    public func cycleTheme() {
        themeManager.toggleTheme()
    }
}
