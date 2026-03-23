//

//
//  DealDisplayPictureView.swift
//  BridgeTeacherHandCompose
//
//  Created by Gerald Dawson on 13/1/2026.
//
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public enum DisplaySeat: String, CaseIterable { case N, E, S, W }

public enum DisplaySuit: String, CaseIterable {
    case spades = "S", hearts = "H", diamonds = "D", clubs = "C"

    var symbol: String { switch self { case .spades: return "♠︎"; case .hearts: return "♥︎"; case .diamonds: return "♦︎"; case .clubs: return "♣︎" } }
    var isRed: Bool { switch self { case .hearts, .diamonds: return true; default: return false } }
}

public struct DealDisplayData {
    public var board: Int
    public var dealer: DisplaySeat
    public var vulnerability: String
    // ranks are expected in descending order: A,K,Q,J,T,9,...,2
    public var hands: [DisplaySeat: [DisplaySuit: [String]]]

    public init(board: Int, dealer: DisplaySeat, vulnerability: String, hands: [DisplaySeat: [DisplaySuit: [String]]]) {
        self.board = board
        self.dealer = dealer
        self.vulnerability = vulnerability
        self.hands = hands
    }
}

public struct DealDisplayPictureView: View {
    public var sessionFolderURL: URL?
    public var sessionName: String?
    public var deal: DealDisplayData?
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String = ""
    @State private var saveNotesTask: Task<Void, Never>? = nil
    @State private var showLibrary: Bool = false

    public init(sessionFolderURL: URL? = nil, sessionName: String? = nil, deal: DealDisplayData? = nil) {
        self.sessionFolderURL = sessionFolderURL
        self.sessionName = sessionName
        self.deal = deal
    }
    
    private let cardWidth: CGFloat = 81
    private let cardHeight: CGFloat = 122
    private let visibleFraction: CGFloat = 0.45 // show 45% of each preceding card
    private let middleGap: CGFloat = 70 // minimum gap between West and East hands
    private let infoFontSize: CGFloat = 18
    private let groupSpacing: CGFloat = 7
    private let interSuitTightening: CGFloat = 1
    private let headerToCardsSpacing: CGFloat = 10
    private let notesWidthScale: CGFloat = 0.96

    private let baseGreen = Color(red: 46.0/255.0, green: 123.0/255.0, blue: 96.0/255.0)

    private struct GlassButtonStyle: ButtonStyle {
        var labelColor: Color = .primary
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(configuration.isPressed ? 0.16 : 0.08),
                                        Color.blue.opacity(configuration.isPressed ? 0.08 : 0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.5 : 0.35), lineWidth: 1.0)
                            .blendMode(.overlay)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.blue.opacity(configuration.isPressed ? 0.26 : 0.18), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(configuration.isPressed ? 0.08 : 0.14), radius: configuration.isPressed ? 5 : 8, x: 0, y: 3)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }

    private struct SubtleBorderButtonStyle: ButtonStyle {
        var labelColor: Color = .primary
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(configuration.isPressed ? 0.22 : 0.16),
                                        Color.white.opacity(configuration.isPressed ? 0.10 : 0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.55 : 0.40), lineWidth: 0.9)
                        .blendMode(.overlay)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(configuration.isPressed ? 0.28 : 0.22), lineWidth: 2.5)
                )
                .opacity(configuration.isPressed ? 0.92 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }

    private struct RecordButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.red.opacity(configuration.isPressed ? 0.35 : 0.0), lineWidth: 2)
                )
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .shadow(color: Color.red.opacity(configuration.isPressed ? 0.25 : 0.0), radius: configuration.isPressed ? 8 : 0, x: 0, y: 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
        }
    }

    private func aggregateSessionIfPossible() {
        guard let folderURL = sessionFolderURL, let name = sessionName else { return }
        Task {
            do {
                let fm = FileManager.default
                // Small delay to avoid reading files mid-write
                try await Task.sleep(nanoseconds: 200_000_000)

                let contents = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                let pbnFiles = contents.filter { $0.pathExtension.lowercased() == "pbn" }

                func boardNumber(from url: URL) -> Int? {
                    let base = url.deletingPathExtension().lastPathComponent
                    if let r = base.range(of: "\\d+", options: .regularExpression) { return Int(base[r]) }
                    return nil
                }

                let sorted = pbnFiles.sorted { a, b in
                    switch (boardNumber(from: a), boardNumber(from: b)) {
                    case let (x?, y?): return x < y
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: return a.lastPathComponent < b.lastPathComponent
                    }
                }

                print("Aggregator found PBNs: \(sorted.map { $0.lastPathComponent })")

                var parts: [String] = []
                for file in sorted {
                    do {
                        let data = try Data(contentsOf: file)
                        if var s = String(data: data, encoding: .utf8) {
                            // Normalise to end with a single new line
                            while s.hasSuffix("\n") { s.removeLast() }
                            s.append("\n")
                            parts.append(s)
                            print("Included: \(file.lastPathComponent)")
                        } else {
                            print("Skipped (encoding): \(file.lastPathComponent)")
                        }
                    } catch {
                        print("Skipped (read error): \(file.lastPathComponent) — \(error)")
                    }
                }

                guard !parts.isEmpty else { print("No PBN fragments to aggregate"); return }
                // Separate deals with a blank line
                let aggregate = parts.joined(separator: "\n") + "\n"

                let destURL = folderURL.deletingLastPathComponent().appendingPathComponent("\(name).pbn")
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try aggregate.write(to: destURL, atomically: true, encoding: .utf8)
                print("Aggregated session to: \(destURL.path)")
            } catch {
                print("Aggregation failed: \(error)")
            }
        }
    }

    private func notesURL(for board: Int) -> URL? {
        guard let folder = sessionFolderURL, board > 0 else { return nil }
        return folder.appendingPathComponent("Board \(board).notes.txt")
    }

    private func loadNotesIfAvailable() {
        guard let b = deal?.board, b > 0, let url = notesURL(for: b) else { return }
        if let data = try? Data(contentsOf: url), let s = String(data: data, encoding: .utf8) {
            notes = s
        } else {
            notes = ""
        }
    }

    private func saveNotes() {
        guard let b = deal?.board, b > 0, let url = notesURL(for: b) else { return }
        do {
            try notes.write(to: url, atomically: true, encoding: .utf8)
            print("Saved notes to: \(url.lastPathComponent)")
        } catch {
            print("Failed to save notes: \(error)")
        }
    }

    private func saveSnapshot() {
        guard let b = deal?.board, b > 0 else {
            print("Snapshot skipped: invalid board number.")
            return
        }
        guard let folder = sessionFolderURL else {
            print("Snapshot skipped: no session folder available.")
            return
        }
        let fileURL = folder.appendingPathComponent("Board \(b).jpg")

        // Build a snapshot-optimised view: no controls, constrained width, simplified background
        let snapshotView = content(notesView: notesSnapshotView(), showControls: false, snapshotMode: true)
            .frame(width: 1600)

        let renderer = ImageRenderer(content: snapshotView)
        // Let the view size itself to its ideal size
        renderer.proposedSize = .unspecified
    #if os(macOS)
        // Change Render to between 1-2 to reduce pixel count and file size if necessary; 1x isn't very good I notice
        renderer.scale = 2.0
        
        renderer.isOpaque = true
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           // Reduce the compression factor to say 0.85 to reduce file size if needed
           let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.90]) {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try jpegData.write(to: fileURL, options: .atomic)
                print("Saved snapshot to: \(fileURL.lastPathComponent) (\(jpegData.count) bytes)")
            } catch {
                print("Failed to save snapshot: \(error)")
            }
        } else {
            print("Failed to render snapshot image.")
        }
    #else
        print("Snapshot currently implemented for macOS only.")
    #endif
    }

    private func addCurrentHand(to categoryName: String) {
        guard let folder = sessionFolderURL,
              let name = sessionName,
              let board = deal?.board, board > 0 else {
            print("Cannot file: missing session, name, or board.")
            return
        }

        let fm = FileManager.default
        let sourcePBN = folder.appendingPathComponent("Board \(board).pbn")
        let sourceNotes = folder.appendingPathComponent("Board \(board).notes.txt")
        let sourceJPG = folder.appendingPathComponent("Board \(board).jpg")

        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let sanitizedCategory = categoryName.components(separatedBy: illegal).joined(separator: "-")
        let sanitizedSession = name.components(separatedBy: illegal).joined(separator: "-")

        do {
            let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let library = docs.appendingPathComponent("BridgeLibrary", isDirectory: true)
            let categories = library.appendingPathComponent("Categories", isDirectory: true)
            let destFolder = categories.appendingPathComponent(sanitizedCategory, isDirectory: true)
            try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)

            func copyIfExists(_ src: URL, as destName: String) throws {
                if fm.fileExists(atPath: src.path) {
                    let dest = destFolder.appendingPathComponent(destName)
                    if fm.fileExists(atPath: dest.path) {
                        try fm.removeItem(at: dest)
                    }
                    try fm.copyItem(at: src, to: dest)
                    print("Filed: \(dest.lastPathComponent)")
                }
            }

            try copyIfExists(sourcePBN, as: "\(sanitizedSession)-Board-\(board).pbn")
            try copyIfExists(sourceNotes, as: "\(sanitizedSession)-Board-\(board).notes.txt")
            try copyIfExists(sourceJPG, as: "\(sanitizedSession)-Board-\(board).jpg")
        } catch {
            print("Failed to file to category '\(categoryName)': \(error)")
        }
    }

    // MARK: - Snapshot-aware content builders

    private func notesEditorView() -> some View {
        HStack {
            TextEditor(text: $notes)
                .font(.title3)
                .frame(width: widthForSeat(.S) * notesWidthScale, height: 200)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func notesSnapshotView() -> some View {
        HStack {
            Text(notes)
                .font(.title3)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .frame(width: widthForSeat(.S) * notesWidthScale, height: 200, alignment: .topLeading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func content<NV: View>(notesView: NV, showControls: Bool = true, snapshotMode: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top, spacing: 12) {
                // Board info panel (top-left)
                boardInfoPanel
                if showControls {
                    Spacer()
                    Button(action: { showLibrary = true }) {
                        Text("Library⊕")
                    }
                    .buttonStyle(RecordButtonStyle())
                    Button(action: {
                        saveNotes()
                        saveSnapshot()
                    }) {
                        Text("Record")
                    }
                    .buttonStyle(RecordButtonStyle())
                    
                    Button(action: { dismiss() }) {
                        Text("Next Hand")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
            }

            // North at top center
            VStack(spacing: headerToCardsSpacing) {
                seatHeader(.N)
                cardsRow(for: .N)
            }
            .frame(maxWidth: .infinity)

            // Middle row: West (left) and East (right)
            HStack(alignment: .top) {
                if snapshotMode {
                    // Use a fixed center gap in snapshot mode so it matches the sheet's intended gap.
                    VStack(spacing: headerToCardsSpacing) {
                        seatHeader(.W)
                        cardsRow(for: .W)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    Color.clear.frame(width: middleGap)

                    VStack(spacing: headerToCardsSpacing) {
                        seatHeader(.E)
                        cardsRow(for: .E)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: headerToCardsSpacing) {
                        seatHeader(.W)
                        cardsRow(for: .W)
                    }
                    Spacer(minLength: middleGap)
                    VStack(spacing: headerToCardsSpacing) {
                        seatHeader(.E)
                        cardsRow(for: .E)
                    }
                }
            }

            // South at bottom center
            VStack(spacing: headerToCardsSpacing) {
                seatHeader(.S)
                cardsRow(for: .S)
            }
            .frame(maxWidth: .infinity)

            // Notes area
            notesView
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding()
        .background(
            ZStack {
                Rectangle().fill(baseGreen)

                if !snapshotMode {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.12)
                }

                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 46.0/255.0, green: 123.0/255.0, blue: 96.0/255.0), location: 0.0),
                        .init(color: Color(red: 11.0/255.0, green: 61.0/255.0,  blue: 46.0/255.0), location: 0.55),
                        .init(color: Color(red: 6.0/255.0,  green: 40.0/255.0,  blue: 32.0/255.0), location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 900
                )
                .opacity(0.55)
            }
            .ignoresSafeArea()
        )
    }

    public var body: some View {
        content(notesView: notesEditorView())
            .onAppear {
                aggregateSessionIfPossible()
                loadNotesIfAvailable()
            }
            .onChange(of: deal?.board ?? 0) { _, _ in
                loadNotesIfAvailable()
            }
            .onChange(of: notes) { _, _ in
                saveNotesTask?.cancel()
                saveNotesTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run { saveNotes() }
                }
            }
            .onDisappear {
                saveNotesTask?.cancel()
                saveNotes()
            }
            .sheet(isPresented: $showLibrary) {
                DealLibraryView(
                    sessionFolderURL: sessionFolderURL,
                    sessionName: sessionName,
                    onCategoryChosen: { category in
                        addCurrentHand(to: category)
                    }
                )
            }
    }

    private var boardInfoPanel: some View {
        let b = deal?.board ?? 0
        let d = b > 0 ? standardDealer(forBoard: b).rawValue : (deal?.dealer.rawValue ?? "N")
        let v = b > 0 ? standardVulnerability(forBoard: b) : (deal?.vulnerability ?? "None")
        return VStack(alignment: .leading, spacing: 9) {
            infoRow(label: "Board:", value: b == 0 ? "—" : String(b))
            infoRow(label: "Dealer:", value: d)
            infoRow(label: "Vul:", value: v)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.quaternary, lineWidth: 1.5)
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: infoFontSize, weight: .bold))
            Text(value).font(.system(size: infoFontSize))
        }
    }
    
    // Standard duplicate bridge rotation
    private func standardDealer(forBoard board: Int) -> DisplaySeat {
        guard board > 0 else { return .N }
        let index = (board - 1) % 4
        switch index {
        case 0: return .N
        case 1: return .E
        case 2: return .S
        default: return .W
        }
    }

    // Standard duplicate bridge vulnerability cycle across 16 boards
    private func standardVulnerability(forBoard board: Int) -> String {
        guard board > 0 else { return "None" }
        let idx = ((board - 1) % 16) + 1
        switch idx {
        case 1, 8, 11, 14:
            return "None"
        case 2, 5, 12, 15:
            return "N/S"
        case 3, 6, 9, 16:
            return "E/W"
        case 4, 7, 10, 13:
            return "Both"
        default:
            return "None"
        }
    }

    private func hcp(for seat: DisplaySeat) -> Int {
        guard let seatHands = deal?.hands[seat] else { return 0 }
        let points: [String: Int] = ["A": 4, "K": 3, "Q": 2, "J": 1]
        var total = 0
        for (_, ranks) in seatHands {
            for r in ranks { total += points[r] ?? 0 }
        }
        return total
    }

    private func hcpBadge(for seat: DisplaySeat) -> some View {
        let value = hcp(for: seat)
        return Text("HCP: \(value)")
            .font(.callout)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.yellow)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
    }

    private func seatDisplayName(_ seat: DisplaySeat) -> String {
        switch seat {
        case .N: return "NORTH"
        case .E: return "EAST"
        case .S: return "SOUTH"
        case .W: return "WEST"
        }
    }

    private func seatHeader(_ seat: DisplaySeat) -> some View {
        HStack(spacing: 10) {
            Text(seatDisplayName(seat))
                .font(.headline)
                .foregroundStyle(Color.yellow)
            hcpBadge(for: seat)
        }
    }

    private func cardsRow(for seat: DisplaySeat) -> some View {
        let groups = cardGroups(for: seat)
        return HStack(alignment: .bottom, spacing: groupSpacing) {
            ForEach(groups.indices, id: \.self) { idx in
                overlappedGroup(for: groups[idx])
                    .padding(.trailing, idx < groups.count - 1 ? -interSuitTightening : 0)
            }
        }
    }
    
    private func widthForSeat(_ seat: DisplaySeat) -> CGFloat {
        let groups = cardGroups(for: seat)
        let step = cardWidth * visibleFraction
//        let spacings = groupSpacing * CGFloat(max(groups.count - 1, 0))
        let effectiveSpacing = max(groupSpacing - interSuitTightening, 0)
        let spacings = effectiveSpacing * CGFloat(max(groups.count - 1, 0))
        let totalGroupsWidth = groups.reduce(CGFloat(0)) { partial, codes in
            let count = codes.count
            let groupWidth = cardWidth + step * CGFloat(max(count - 1, 0))
            return partial + groupWidth
        }
        return totalGroupsWidth + spacings
    }

    private func overlappedGroup(for codes: [String]) -> some View {
        let step = cardWidth * visibleFraction
        let cardHeight = self.cardHeight // height decoupled from width
        let totalWidth = cardWidth + step * CGFloat(max(codes.count - 1, 0))
        return ZStack(alignment: .leading) {
            ForEach(Array(codes.enumerated()), id: \.offset) { index, code in
                cardView(code: code)
                    .frame(width: cardWidth, height: cardHeight)
                    .shadow(radius: 2)
                    .offset(x: CGFloat(index) * step)
                    .zIndex(Double(index)) // later cards (lower ranks) appear on top
            }
        }
        .frame(width: totalWidth, alignment: .leading)
    }

    // Build card groups by suit in order: spades, hearts, diamonds, clubs
    private func cardGroups(for seat: DisplaySeat) -> [[String]] {
        guard let seatHands = deal?.hands[seat] else { return [] }
        let order: [DisplaySuit] = [.spades, .hearts, .diamonds, .clubs]
        let rankOrder = ["A","K","Q","J","T","9","8","7","6","5","4","3","2"]
        return order.map { suit in
            let ranks = seatHands[suit] ?? []
            let sorted = rankOrder.filter { ranks.contains($0) }
            // Map to code e.g., "AS", "TD"
            return sorted.map { cardCode(for: suit, rank: $0) }
        }.filter { !$0.isEmpty }
    }

    private func cardCode(for suit: DisplaySuit, rank: String) -> String {
        
        return rank + suit.rawValue
    }

    private func cardView(code: String) -> some View {
        // Expect codes like "AS", "TD" where last char is suit (S/H/D/C) and preceding is rank
        guard let suitChar = code.last,
              let suit = DisplaySuit(rawValue: String(suitChar)) else {
            return AnyView(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Text(code).font(.headline))
            )
        }
        let rankCode = String(code.dropLast()) // e.g., "A","K","Q","J","T","9"
        return AnyView(
            PlayingCardView(rankCode: rankCode, suit: suit)
        )
    }
}

#Preview {
    let sampleHands: [DisplaySeat: [DisplaySuit: [String]]] = [
        .N: [.spades: ["A","K","9"], .hearts: ["Q","J"], .diamonds: ["A","K","Q","J","T","9"], .clubs: ["3","2"]],
        .E: [.spades: ["J","8"], .hearts: ["8","6"], .diamonds: ["K","3"], .clubs: ["K","Q","J"]],
        .S: [.spades: ["A","5"], .hearts: ["A","K","Q"], .diamonds: ["5","4","3"], .clubs: ["A","9","8","7"]],
        .W: [.spades: ["Q","T"], .hearts: ["A","7","4"], .diamonds: ["A","7","2"], .clubs: ["T","9","6"]]
    ]
    let sample = DealDisplayData(board: 1, dealer: .N, vulnerability: "None", hands: sampleHands)
    return DealDisplayPictureView(sessionFolderURL: nil, sessionName: "My Session", deal: sample)
        .padding()
}

