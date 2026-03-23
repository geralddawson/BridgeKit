// FilePreviewView.swift
// Extracted from DealLibraryView.swift

import SwiftUI
import Foundation
import AppKit

struct FilePreviewView: View {
    let fileURL: URL

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var selection: SessionDealSelection
    @State private var showSelectionLimitAlert: Bool = false
    @State private var textContent: String? = nil
    @State private var imageData: Data? = nil
    @State private var loadError: String? = nil
    @State private var isProcessingAdd: Bool = false

    private func displayName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        guard ext == "pbn" else { return url.lastPathComponent }
        let stdPath = url.standardizedFileURL.path
        guard let idx = selection.selectedURLs.firstIndex(where: { $0.standardizedFileURL.path == stdPath }) else {
            return url.lastPathComponent
        }
        let order = idx + 1
        var base = url.deletingPathExtension().lastPathComponent
        if base.hasPrefix("#") {
            base.removeFirst()
        }
        if let underscoreIndex = base.firstIndex(of: "_") {
            let prefix = base[..<underscoreIndex]
            if Int(prefix) != nil {
                base = String(base[base.index(after: underscoreIndex)...])
            }
        }
        return "#\(order)_\(base).\(url.pathExtension)"
    }

    private var fileExtension: String { fileURL.pathExtension.lowercased() }

    private var renumberedPBNPreview: String? {
        guard fileExtension == "pbn" else { return nil }
        guard selection.contains(fileURL) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let original = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        if let board = selection.intendedBoardNumber(for: fileURL) {
            return SessionDealSelection.renumberPBN(original, to: board)
        } else {
            return original
        }
    }

    var body: some View {
        Group {
            if let data = imageData {
                if let image = NSImage(data: data) {
                    ScrollView { Image(nsImage: image).resizable().scaledToFit().padding() }
                } else { Text("Unable to render image.").foregroundColor(.secondary).padding() }
            } else if fileExtension == "pbn" {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        #if os(macOS)
                        Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path)).resizable().frame(width: 32, height: 32)
                        #else
                        Image(systemName: "doc.text").font(.system(size: 32))
                        #endif
                        Text("PBN file").font(.headline)
                    }
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
                        if let size = attrs[.size] as? NSNumber { Text(String(format: "Size: %.1f KB", Double(truncating: size) / 1024)) }
                        if let mod = attrs[.modificationDate] as? Date { Text("Modified: \(mod.formatted(date: .abbreviated, time: .shortened))") }
                    }
                    ScrollView {
                        Text(renumberedPBNPreview ?? (textContent ?? ""))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else if let text = textContent {
                ScrollView { Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
            } else if let err = loadError {
                Text(err).foregroundColor(.secondary).padding()
            } else {
                ProgressView().padding()
            }
        }
        .disabled(isProcessingAdd)
        .overlay(alignment: .center) {
            if isProcessingAdd {
                ZStack {
                    Color.black.opacity(0.1).ignoresSafeArea()
                    VStack(spacing: 10) { ProgressView(); Text("Adding…").font(.headline) }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .navigationTitle(displayName(for: fileURL))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack {
                    if fileExtension == "pbn" {
                        if !selection.contains(fileURL) {
                            Button {
                                if !selection.add(fileURL) {
                                    showSelectionLimitAlert = true
                                } else {
                                    isProcessingAdd = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        NotificationCenter.default.post(name: .closePreviewAndReturnToCategories, object: nil)
                                        isProcessingAdd = false
                                    }
                                }
                            } label: { Label("Add", systemImage: "plus.circle") }
                        }
                    }
                    Spacer()
                    if fileExtension == "jpg" || fileExtension == "txt" {
                        Button { revealInFinder() } label: { Label("Reveal in Finder", systemImage: "folder") }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { load() }
        .alert("Selection limit reached", isPresented: $showSelectionLimitAlert) { Button("OK", role: .cancel) {} } message: { Text("You can select up to \(selection.maxBoards) boards.") }
    }

    private func load() {
        do {
            if ["jpg", "jpeg", "png"].contains(fileExtension) {
                imageData = try Data(contentsOf: fileURL)
            } else if ["txt", "json", "md", "log"].contains(fileExtension) {
                let data = try Data(contentsOf: fileURL)
                if fileExtension == "json" {
                    if let obj = try? JSONSerialization.jsonObject(with: data),
                       let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
                       let s = String(data: pretty, encoding: .utf8) { textContent = s }
                    else { textContent = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self) }
                } else { textContent = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self) }
            } else if fileExtension == "pbn" {
                let data = try Data(contentsOf: fileURL)
                textContent = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            } else { loadError = "No inline preview available for .\(fileExtension.uppercased())." }
        } catch { loadError = "Failed to load file: \(error.localizedDescription)" }
    }

    private func revealInFinder() { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) }
    private func openExternally() { NSWorkspace.shared.open(fileURL) }
}

