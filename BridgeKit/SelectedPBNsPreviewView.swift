// SelectedPBNsPreviewView.swift
// Extracted from DealLibraryView.swift

import SwiftUI

struct SelectedPBNsPreviewView: View {
    let initialURL: URL

    @EnvironmentObject private var selection: SessionDealSelection
    @State private var currentURL: URL

    init(initialURL: URL) {
        let std = initialURL.standardizedFileURL
        self.initialURL = std
        _currentURL = State(initialValue: std)
    }

    private var urls: [URL] {
        var urls = selection.selectedURLs.map { $0.standardizedFileURL }
        let initial = initialURL.standardizedFileURL
        if !urls.contains(where: { $0.standardizedFileURL.path == initial.path }) {
            urls.append(initial)
        }
        return urls
    }

    private var currentURLSelection: Binding<URL?> {
        Binding<URL?>(
            get: { currentURL },
            set: { newValue in if let newValue { currentURL = newValue } }
        )
    }

    private func displayName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        guard ext == "pbn" else { return url.lastPathComponent }
        let stdPath = url.standardizedFileURL.path
        guard let idx = selection.selectedURLs.firstIndex(where: { $0.standardizedFileURL.path == stdPath }) else {
            return url.lastPathComponent
        }
        let order = idx + 1
        var base = url.deletingPathExtension().lastPathComponent
        if base.hasPrefix("#") { base.removeFirst() }
        if let underscoreIndex = base.firstIndex(of: "_") {
            let prefix = base[..<underscoreIndex]
            if Int(prefix) != nil { base = String(base[base.index(after: underscoreIndex)...]) }
        }
        return "#\(order)_\(base).\(url.pathExtension)"
    }

    var body: some View {
        NavigationSplitView {
            List(urls, id: \.self, selection: currentURLSelection) { url in
                HStack(spacing: 8) { Image(systemName: "doc.text"); Text(displayName(for: url)) }
            }
            .frame(minWidth: 220)
        } detail: {
            if urls.isEmpty { Text("No files to preview").foregroundColor(.secondary) }
            else { FilePreviewView(fileURL: currentURL) }
        }
        .onChange(of: selection.selectedURLs) { _, _ in
            let all = urls
            if !all.contains(where: { $0.standardizedFileURL.path == currentURL.standardizedFileURL.path }) {
                if let first = all.first { currentURL = first } else { currentURL = initialURL }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { NotificationCenter.default.post(name: .closePreviewAndReturnToCategories, object: nil) } label: { Label("Close", systemImage: "xmark.circle") }
            }
            ToolbarItem(placement: .automatic) {
                if currentURL.pathExtension.lowercased() == "pbn" && selection.contains(currentURL) {
                    Button { selection.remove(currentURL) } label: { Label("Remove", systemImage: "checkmark.circle.fill") }
                }
            }
        }
    }
}

