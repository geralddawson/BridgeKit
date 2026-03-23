import SwiftUI
import Foundation
import Combine
import AppKit

struct DealLibraryView: View {
    @Environment(\.dismiss) private var dismiss

    let sessionFolderURL: URL?
    let sessionName: String?
    let onCategoryChosen: ((String) -> Void)?

    init(sessionFolderURL: URL?, sessionName: String?, onCategoryChosen: ((String) -> Void)? = nil) {
        self.sessionFolderURL = sessionFolderURL
        self.sessionName = sessionName
        self.onCategoryChosen = onCategoryChosen
    }

    private struct Category: Identifiable, Codable, Equatable, Hashable {
        var id: UUID
        var name: String
        var createdAt: Date

        init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
        }
    }

    @State private var categories: [Category] = []
    @State private var newCategoryName: String = ""
    @State private var categoryError: String? = nil
    @FocusState private var addFieldFocused: Bool
    @State private var showAddPopover: Bool = false
    private let addRowID = "AddCategoryRow"

    @State private var editingCategoryID: UUID? = nil
    @State private var editedCategoryName: String = ""
    @FocusState private var renameFieldFocused: Bool
    @StateObject private var selection = SessionDealSelection(maxBoards: 24)
    // Removed @State private var selectedCategoryID: UUID? = nil
    @State private var showingCategory: Category? = nil

    @State private var showAggregateSheet: Bool = false
    @State private var aggregateFileName: String = ""
    @State private var aggregateErrorMessage: String? = nil
    @State private var lastSavedAggregatedURL: URL? = nil
    @State private var showAggregateSuccessAlert: Bool = false

    @ViewBuilder
    private func categoryRow(for cat: Category) -> some View {
        HStack(spacing: 10) {
            if onCategoryChosen != nil {
                Button {
                    commitSelection(for: cat)
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }

            if editingCategoryID == cat.id {
                TextField("Category name", text: $editedCategoryName)
                    .textFieldStyle(.roundedBorder)
                    .focused($renameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { commitRename(for: cat) }
            } else {
                Text(cat.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                    .help(cat.name)
            }
            Spacer()

            if editingCategoryID == cat.id {
                HStack(spacing: 8) {
                    Button {
                        commitRename(for: cat)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        cancelRename()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        showingCategory = cat
                    } label: {
                        Label("View", systemImage: "eye")
                    }
                    Button {
                        startEditing(cat)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var addCategoryInputRow: some View {
        HStack {
            TextField("New category name", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
                .focused($addFieldFocused)
                .submitLabel(.done)
                .onSubmit { addCategory() }
            Button("Add") { addCategory() }
                .buttonStyle(.borderedProminent)
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .id(addRowID)
    }

    @ViewBuilder
    private var categoriesSection: some View {
        Section(header: Text("Categories")) {
            if categories.isEmpty {
                Text("No categories yet. Type a name below and tap Add.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(categories, id: \.id) { cat in
                    categoryRow(for: cat)
                }
                .onDelete(perform: deleteCategories)
                .onMove(perform: moveCategories)
            }

            addCategoryInputRow

            if let categoryError = categoryError {
                Text(categoryError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    categoriesSection

                    if let sessionName = sessionName {
                        Section {
                            Text(sessionName)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.inset)
                .navigationTitle("Library")
                .navigationDestination(item: $showingCategory) { cat in
                    CategoryHandsView(categoryName: cat.name, onClose: { showingCategory = nil })
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            aggregateErrorMessage = nil
                            aggregateFileName = defaultAggregatedFileName()
                            showAggregateSheet = true
                        } label: {
                            Label("Build Session", systemImage: "doc.badge.plus")
                        }
                        .disabled(selection.count == 0)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            // TODO: Implement select action
                        } label: {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .sheet(isPresented: $showAggregateSheet) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Build Session").font(.headline)
                        TextField("File name", text: $aggregateFileName)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                if aggregateFileName.isEmpty {
                                    aggregateFileName = defaultAggregatedFileName()
                                }
                            }
                        if let msg = aggregateErrorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        HStack {
                            Button("Cancel") {
                                showAggregateSheet = false
                                aggregateErrorMessage = nil
                            }
                            Spacer()
                            Button("Save") {
                                let name = aggregateFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if name.isEmpty {
                                    aggregateErrorMessage = "Please enter a file name."
                                } else if let url = saveAggregatedDeals(named: name) {
                                    lastSavedAggregatedURL = url
                                    showAggregateSheet = false
                                    showAggregateSuccessAlert = true
                                } else {
                                    aggregateErrorMessage = "Failed to save session file."
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .frame(width: 360)
                }
                .alert("Session saved", isPresented: $showAggregateSuccessAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    if let url = lastSavedAggregatedURL {
                        Text("Saved as \(url.lastPathComponent)")
                    } else {
                        Text("Saved.")
                    }
                }
                .onChange(of: addFieldFocused) { _, isFocused in
                    if isFocused {
                        withAnimation {
                            proxy.scrollTo(addRowID, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    loadCategories()
                    if categories.isEmpty {
                        addFieldFocused = true
                    }
                }
            }
        }
        .environmentObject(selection)
        .frame(minWidth: 800, minHeight: 600)
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            categoryError = "Please enter a name."
            return
        }
        if categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            categoryError = "Category already exists."
            return
        }
        let new = Category(name: trimmed)
        categories.append(new)
        saveCategories()
        createCategoryFolderIfNeeded(for: trimmed)
        newCategoryName = ""
        categoryError = nil
    }

    private func commitSelection(for cat: Category) {
        if let callback = onCategoryChosen {
            callback(cat.name)
            dismiss()
        } else {
            categoryError = "Open Library from a hand to file into a category."
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        saveCategories()
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        saveCategories()
    }

    private func libraryBaseURL() -> URL? {
        do {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let base = docs.appendingPathComponent("BridgeLibrary", isDirectory: true)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            return base
        } catch {
            return nil
        }
    }

    private func categoriesFileURL() -> URL? {
        guard let base = libraryBaseURL() else { return nil }
        return base.appendingPathComponent("categories.json")
    }

    private func loadCategories() {
        guard let url = categoriesFileURL() else { return }
        do {
            let data = try Data(contentsOf: url)
            if let decoded = try? JSONDecoder().decode([Category].self, from: data) {
                categories = decoded
            } else if let legacy = try? JSONDecoder().decode([String].self, from: data) {
                categories = legacy.map { Category(name: $0) }
                saveCategories()
            } else {
                categories = []
            }
        } catch {
            categories = []
        }
    }

    private func saveCategories() {
        guard let url = categoriesFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(categories)
            try data.write(to: url, options: .atomic)
        } catch {
            // Silent failure for now; consider surfacing an error if needed
        }
    }

    private func defaultAggregatedFileName() -> String {
        if let sessionName = sessionName, !sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let base = sanitizeFileName(sessionName)
            return base.lowercased().hasSuffix(".pbn") ? base : "\(base).pbn"
        }
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        return "Session_\(df.string(from: Date())).pbn"
    }

    private func sanitizeFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let safe = name.components(separatedBy: illegal).joined(separator: "-")
        let trimmed = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(80))
    }

    private func sessionsFolderURL() -> URL? {
        if let folder = sessionFolderURL {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                return folder
            } catch {
                return nil
            }
        }
        guard let base = libraryBaseURL() else { return nil }
        let sessions = base.appendingPathComponent("Sessions", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
            return sessions
        } catch {
            return nil
        }
    }

    private func uniqueURL(in folder: URL, withBaseName baseName: String, fileExtension ext: String) -> URL {
        let base = baseName
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var idx = 1
        while FileManager.default.fileExists(atPath: candidate.path) && idx < 10000 {
            candidate = folder.appendingPathComponent("\(base)-\(idx)").appendingPathExtension(ext)
            idx += 1
        }
        return candidate
    }

    private func aggregateSelectedDealsContent() -> String? {
        let items = selection.selectedURLs
        guard !items.isEmpty else { return nil }
        var parts: [String] = []
        for url in items {
            if let s = selection.renumberedPBNString(for: url) {
                parts.append(s.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }

    @discardableResult
    private func saveAggregatedDeals(named inputName: String) -> URL? {
        guard let folder = sessionsFolderURL() else { return nil }
        let sanitized = sanitizeFileName(inputName)
        let base = sanitized.lowercased().hasSuffix(".pbn") ? String(sanitized.dropLast(4)) : sanitized
        let target = uniqueURL(in: folder, withBaseName: base, fileExtension: "pbn")
        guard let content = aggregateSelectedDealsContent() else { return nil }
        do {
            try content.data(using: .utf8)?.write(to: target, options: .atomic)
            return target
        } catch {
            return nil
        }
    }

    private func sanitizeCategoryName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let safe = name.components(separatedBy: illegal).joined(separator: "-")
        return String(safe.prefix(60))
    }

    private func createCategoryFolderIfNeeded(for displayName: String) {
        guard let base = libraryBaseURL() else { return }
        let categoriesDir = base.appendingPathComponent("Categories", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: categoriesDir, withIntermediateDirectories: true)
            let sanitized = sanitizeCategoryName(displayName)
            let folder = categoriesDir.appendingPathComponent(sanitized, isDirectory: true)
            if !FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
        } catch {
        }
    }

    private func startEditing(_ cat: Category) {
        editedCategoryName = cat.name
        editingCategoryID = cat.id
        categoryError = nil
        renameFieldFocused = true
    }

    private func cancelRename() {
        editingCategoryID = nil
        editedCategoryName = ""
        categoryError = nil
        renameFieldFocused = false
    }

    private func commitRename(for cat: Category) {
        let trimmed = editedCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            categoryError = "Please enter a name."
            renameFieldFocused = true
            return
        }
        if cat.name.caseInsensitiveCompare(trimmed) == .orderedSame {
            cancelRename()
            return
        }
        // Prevent duplicate display names
        if categories.contains(where: { $0.id != cat.id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            categoryError = "Category already exists."
            renameFieldFocused = true
            return
        }
        let newSan = sanitizeCategoryName(trimmed)
        let collision = categories.contains { c in
            c.id != cat.id && sanitizeCategoryName(c.name).caseInsensitiveCompare(newSan) == .orderedSame
        }
        if collision {
            categoryError = "Category already exists."
            renameFieldFocused = true
            return
        }

        // Attempt folder rename if needed; abort on failure
        guard renameCategoryFolderIfNeeded(from: cat.name, to: trimmed) else {
            renameFieldFocused = true
            return
        }

        // Update the model and persist
        if let idx = categories.firstIndex(where: { $0.id == cat.id }) {
            categories[idx].name = trimmed
        }
        saveCategories()
        cancelRename()
    }

    private func renameCategoryFolderIfNeeded(from oldName: String, to newName: String) -> Bool {
        guard let base = libraryBaseURL() else { return false }
        let categoriesDir = base.appendingPathComponent("Categories", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: categoriesDir, withIntermediateDirectories: true)
            let oldSan = sanitizeCategoryName(oldName)
            let newSan = sanitizeCategoryName(newName)

            if oldSan.caseInsensitiveCompare(newSan) == .orderedSame {
                return true
            }

            let oldURL = categoriesDir.appendingPathComponent(oldSan, isDirectory: true)
            let newURL = categoriesDir.appendingPathComponent(newSan, isDirectory: true)

            var isDir: ObjCBool = false
            let oldExists = FileManager.default.fileExists(atPath: oldURL.path, isDirectory: &isDir)
            let newExists = FileManager.default.fileExists(atPath: newURL.path, isDirectory: nil)

            if oldExists && isDir.boolValue {
                if newExists {
                    categoryError = "A folder with that name already exists."
                    return false
                }
                try FileManager.default.moveItem(at: oldURL, to: newURL)
            } else {
                if !newExists {
                    try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: true)
                }
            }
            return true
        } catch {
            categoryError = "Failed to rename folder: \(error.localizedDescription)"
            return false
        }
    }

    private struct CategoryHandsView: View {
        let categoryName: String
        let onClose: (() -> Void)?
        @Environment(\.dismiss) private var dismiss
        @State private var handFiles: [URL] = []
        @State private var errorMessage: String? = nil

        @State private var previewItem: FilePreviewItem? = nil

        private struct FilePreviewItem: Identifiable {
            let url: URL
            var id: String { url.path }
        }

        init(categoryName: String, onClose: (() -> Void)? = nil) {
            self.categoryName = categoryName
            self.onClose = onClose
        }

        var body: some View {
            List {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                } else if handFiles.isEmpty {
                    Text("No hands in this category yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(handFiles.enumerated()), id: \.element) { _, url in
                        Button {
                            let ext = url.pathExtension.lowercased()
                            if ext == "pbn" {
                                previewItem = FilePreviewItem(url: url)
                            } else if ext == "jpg" || ext == "txt" {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(url.lastPathComponent)
                                    .font(.title3)
                                HStack(spacing: 12) {
                                    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                                        if let size = attrs[.size] as? NSNumber {
                                            Text(String(format: "%.1f KB", Double(truncating: size) / 1024))
                                        }
                                        if let mod = attrs[.modificationDate] as? Date {
                                            Text(mod.formatted(date: .abbreviated, time: .omitted))
                                        }
                                    }
                                }
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .help({
                            let ext = url.pathExtension.lowercased()
                            return ext == "pbn" ? "Open PBN" : ((ext == "jpg" || ext == "txt") ? "Reveal in Finder" : "Only PBN files can be opened")
                        }())
                        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteHandFile(url)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteHandFile(url)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteHandFile(url)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            if ["jpg", "txt"].contains(url.pathExtension.lowercased()) {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                } label: {
                                    Label("Reveal in Finder", systemImage: "folder")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle(categoryName)
            .onAppear { loadHands() }
            .onReceive(NotificationCenter.default.publisher(for: .closePreviewAndReturnToCategories)) { _ in
                previewItem = nil
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
            .sheet(item: $previewItem) { item in
                SelectedPBNsPreviewView(initialURL: item.url)
                    .frame(minWidth: 520, minHeight: 300)
                    .onDisappear { previewItem = nil }
            }
        }

        private func deleteHandFile(_ url: URL) {
            do {
                try FileManager.default.removeItem(at: url)
                handFiles.removeAll { $0 == url }
            } catch {
                // Silent failure for now; consider surfacing an alert if desired
            }
        }

        private func loadHands() {
            guard let base = libraryBaseURL() else {
                errorMessage = "Library location unavailable."
                handFiles = []
                return
            }
            let categoriesDir = base.appendingPathComponent("Categories", isDirectory: true)
            let folder = categoriesDir.appendingPathComponent(sanitizeCategoryName(categoryName), isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let contents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                let allowed = Set(["pbn", "json", "jpg", "jpeg", "png", "txt"])
                let files = contents.filter { allowed.contains($0.pathExtension.lowercased()) }
                handFiles = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
                errorMessage = nil
            } catch {
                errorMessage = "Failed to load hands: \(error.localizedDescription)"
                handFiles = []
            }
        }

        private func libraryBaseURL() -> URL? {
            do {
                let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let base = docs.appendingPathComponent("BridgeLibrary", isDirectory: true)
                try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                return base
            } catch {
                return nil
            }
        }

        private func sanitizeCategoryName(_ name: String) -> String {
            let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            let safe = name.components(separatedBy: illegal).joined(separator: "-")
            return String(safe.prefix(60))
        }
    }
}

#Preview {
    DealLibraryView(
        sessionFolderURL: nil,
        sessionName: "Example Session"
    )
}

