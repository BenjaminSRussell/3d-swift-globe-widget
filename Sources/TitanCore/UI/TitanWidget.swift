#if canImport(SwiftUI) && canImport(MapKit) && os(macOS)
import SwiftUI
import MapKit
import AppKit
import UniformTypeIdentifiers

public struct TitanWidget: View {
    private let container: DependencyContainer

    @State private var dataset: GlobeDataset
    @State private var launchPacket = false
    @State private var cameraRequest: CameraBookmark?
    @State private var currentCamera: CameraBookmark?
    @State private var selectedNodeID: String?
    @State private var bookmarks: [CameraBookmark] = []
    @State private var status: String?

    public init(container: DependencyContainer = .makeDefault()) {
        self.container = container
        self._dataset = State(initialValue: container.dataset)
        self._status = State(initialValue: container.dataLoadError)
    }

    public var body: some View {
        GlobeView(
            dataset: dataset,
            configuration: container.configuration,
            triggerAnimation: $launchPacket,
            cameraRequest: $cameraRequest,
            currentCamera: $currentCamera,
            selectedNodeID: $selectedNodeID
        )
        .ignoresSafeArea()
        // "Global Night" / Deep Stark Tech colour grade
        .contrast(1.3)
        .saturation(0.2)
        .brightness(-0.15)
        .colorMultiply(Color(red: 0.2, green: 0.3, blue: 0.5))
        // HUD bars respect the safe area (#1) instead of fixed padding over the map edges
        .safeAreaInset(edge: .top, spacing: 0) {
            HUDTopBar(
                nodeCount: dataset.nodes.count,
                edgeCount: dataset.edges.count,
                status: status,
                bookmarks: bookmarks,
                onGo: { cameraRequest = $0 },
                onSave: saveCurrentView,
                onDelete: deleteBookmark,
                onExport: exportSession,
                onImport: importSession
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HUDBottomBar(arcCount: dataset.arcs.count) { launchPacket = true }
        }
        .overlay(alignment: .topTrailing) {
            if let id = selectedNodeID, let node = dataset.node(id: id) {
                NodeDetailView(node: node, dataset: dataset) { selectedNodeID = nil }
                    .padding(.top, 64)
                    .padding(.trailing, 16)
            }
        }
        .background(Color.black)
        .onAppear(perform: loadBookmarks)
    }

    // MARK: - Bookmarks (#5)

    private func loadBookmarks() {
        do {
            bookmarks = try container.bookmarkStore.load()
        } catch {
            status = "Bookmarks unreadable: \(error.localizedDescription)"
        }
    }

    private func saveCurrentView() {
        let base = currentCamera ?? container.configuration.initialCamera(for: dataset)
        let bookmark = CameraBookmark(
            name: "View \(bookmarks.count + 1)",
            center: base.center,
            distanceMeters: base.distanceMeters,
            pitch: base.pitch,
            heading: base.heading
        )
        do {
            bookmarks = try container.bookmarkStore.add(bookmark)
            status = "Saved \(bookmark.name)"
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    private func deleteBookmark(_ bookmark: CameraBookmark) {
        do {
            bookmarks = try container.bookmarkStore.remove(id: bookmark.id)
        } catch {
            status = "Delete failed: \(error.localizedDescription)"
        }
    }

    private func exportSession() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "titan-session.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try GlobeSession(dataset: dataset, bookmarks: bookmarks).export().write(to: url, options: .atomic)
            status = "Exported \(url.lastPathComponent)"
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importSession() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, UTType(filenameExtension: "geojson") ?? .json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            if let session = try? GlobeSession.importSession(data) {
                dataset = session.dataset
                try container.bookmarkStore.save(session.bookmarks)
                bookmarks = session.bookmarks
                status = "Imported session: \(session.dataset.nodes.count) nodes, \(session.bookmarks.count) bookmarks"
            } else {
                dataset = try GlobeDataLoader.load(data: data)
                status = "Loaded \(url.lastPathComponent): \(dataset.nodes.count) nodes"
            }
            selectedNodeID = nil
        } catch {
            status = "Import failed: \(error)"
        }
    }
}

// MARK: - HUD

struct HUDTopBar: View {
    let nodeCount: Int
    let edgeCount: Int
    let status: String?
    let bookmarks: [CameraBookmark]
    let onGo: (CameraBookmark) -> Void
    let onSave: () -> Void
    let onDelete: (CameraBookmark) -> Void
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("TITAN ENGINE: ACTIVE")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.cyan)
            Text("\(nodeCount) nodes · \(edgeCount) links")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
            if let status = status {
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Menu {
                if bookmarks.isEmpty {
                    Text("No bookmarks yet")
                }
                ForEach(bookmarks) { bookmark in
                    Button(bookmark.name) { onGo(bookmark) }
                }
                Divider()
                Button("Save Current View", action: onSave)
                if !bookmarks.isEmpty {
                    Menu("Delete") {
                        ForEach(bookmarks) { bookmark in
                            Button(bookmark.name) { onDelete(bookmark) }
                        }
                    }
                }
                Divider()
                Button("Export Session…", action: onExport)
                Button("Import Session / GeoJSON…", action: onImport)
            } label: {
                Label("Bookmarks", systemImage: "bookmark")
            }
            .fixedSize()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

struct HUDBottomBar: View {
    let arcCount: Int
    let onLaunch: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onLaunch) {
                HStack {
                    Image(systemName: "location.north.circle.fill")
                    Text(arcCount > 0 ? "LAUNCH PACKETS (\(arcCount))" : "LAUNCH PACKETS")
                }
                .padding()
                .background(Color.cyan.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(arcCount == 0)
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

/// Node details. Scrolls instead of clipping long IDs / property lists, and its width adapts
/// to the window instead of a fixed 280 pt (#1).
struct NodeDetailView: View {
    let node: GlobeNode
    let dataset: GlobeDataset
    let onClose: () -> Void

    private var links: [String] {
        dataset.edges.compactMap { e in
            if e.from == node.id { return "→ " + (dataset.node(id: e.to)?.name ?? e.to) }
            if e.to == node.id { return "← " + (dataset.node(id: e.from)?.name ?? e.from) }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(node.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
            }
            .padding(12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    row("ID", node.id)
                    row("Lat / Lon", String(format: "%.4f, %.4f", node.coordinate.latitude, node.coordinate.longitude))
                    row("Intensity", "\(node.intensity)")
                    ForEach(node.properties.keys.sorted(), id: \.self) { key in
                        row(key, node.properties[key] ?? "")
                    }
                    if !links.isEmpty {
                        Text("Links").font(.caption).foregroundColor(.secondary).padding(.top, 6)
                        ForEach(links, id: \.self) { Text($0).font(.caption) }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 220, idealWidth: 280, maxWidth: 340)
        .frame(maxHeight: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundColor(.secondary).frame(width: 72, alignment: .leading)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
