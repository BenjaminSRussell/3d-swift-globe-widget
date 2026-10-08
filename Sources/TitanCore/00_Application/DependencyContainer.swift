// DependencyContainer.swift
import Foundation

/// Wires configuration, data and persistence for the widget (#3).
/// The app builds one with `makeDefault()`; tests build one with explicit values.
public struct DependencyContainer: Sendable {
    public let configuration: Configuration
    public let dataset: GlobeDataset
    public let bookmarkStore: BookmarkStore
    /// Set when the configured data file failed to load and the bundled sample was used instead
    public let dataLoadError: String?

    public init(configuration: Configuration, dataset: GlobeDataset, bookmarkStore: BookmarkStore, dataLoadError: String? = nil) {
        self.configuration = configuration
        self.dataset = dataset
        self.bookmarkStore = bookmarkStore
        self.dataLoadError = dataLoadError
    }

    /// Bundled sample network (`Sources/TitanCore/Resources/default_network.geojson`)
    public static func bundledDataset() throws -> GlobeDataset {
        guard let url = Bundle.module.url(forResource: "default_network", withExtension: "geojson") else {
            throw GlobeDataError.malformed("default_network.geojson missing from bundle")
        }
        return try GlobeDataLoader.load(contentsOf: url)
    }

    /// Configuration from the environment, dataset from `dataPath` (falling back to the bundled
    /// sample with `dataLoadError` set), bookmarks at `bookmarksPath` or the default location.
    public static func makeDefault(configuration: Configuration = .fromEnvironment()) -> DependencyContainer {
        var loadError: String?
        var dataset = GlobeDataset.empty
        if let path = configuration.dataPath {
            do {
                dataset = try GlobeDataLoader.load(contentsOf: URL(fileURLWithPath: path))
            } catch {
                loadError = "Could not load \(path): \(error)"
            }
        }
        if dataset.nodes.isEmpty {
            dataset = (try? bundledDataset()) ?? .empty
        }
        let bookmarksURL = configuration.bookmarksPath.map { URL(fileURLWithPath: $0) } ?? BookmarkStore.defaultURL()
        return DependencyContainer(configuration: configuration, dataset: dataset,
                                   bookmarkStore: BookmarkStore(fileURL: bookmarksURL), dataLoadError: loadError)
    }
}
