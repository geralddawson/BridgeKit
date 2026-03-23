// SessionDealSelection.swift
// Extracted from DealLibraryView.swift

import Foundation
import Combine

@MainActor
final class SessionDealSelection: ObservableObject {
    @Published private(set) var selectedURLs: [URL] = []
    let maxBoards: Int

    init(maxBoards: Int = 24) {
        self.maxBoards = maxBoards
    }

    func contains(_ url: URL) -> Bool {
        let p = url.standardizedFileURL.path
        return selectedURLs.contains { $0.standardizedFileURL.path == p }
    }

    @discardableResult
    func add(_ url: URL) -> Bool {
        let std = url.standardizedFileURL
        if contains(std) { return true }
        guard selectedURLs.count < maxBoards else { return false }
        selectedURLs.append(std)
        return true
    }

    func remove(_ url: URL) {
        let p = url.standardizedFileURL.path
        selectedURLs.removeAll { $0.standardizedFileURL.path == p }
    }

    var count: Int { selectedURLs.count }

    func intendedBoardNumber(for url: URL) -> Int? {
        let p = url.standardizedFileURL.path
        guard let idx = selectedURLs.firstIndex(where: { $0.standardizedFileURL.path == p }) else { return nil }
        return idx + 1
    }

    // Compute the dealer for a given board number using the standard rotation: N, E, S, W (repeating).
    static func dealerForBoard(_ boardNumber: Int) -> String {
        switch ((boardNumber - 1) % 4 + 4) % 4 {
        case 0: return "N"
        case 1: return "E"
        case 2: return "S"
        default: return "W"
        }
    }

    // Compute the vulnerability for a given board number using the standard 16-board cycle.
    // Values follow PBN conventions: None, NS, EW, All.
    static func vulnerabilityForBoard(_ boardNumber: Int) -> String {
        let idx = ((boardNumber - 1) % 16 + 16) % 16
        switch idx {
        case 0:  return "None"  // 1
        case 1:  return "NS"    // 2
        case 2:  return "EW"    // 3
        case 3:  return "All"   // 4
        case 4:  return "NS"    // 5
        case 5:  return "EW"    // 6
        case 6:  return "All"   // 7
        case 7:  return "None"  // 8
        case 8:  return "EW"    // 9
        case 9:  return "All"   // 10
        case 10: return "None"  // 11
        case 11: return "NS"    // 12
        case 12: return "All"   // 13
        case 13: return "None"  // 14
        case 14: return "NS"    // 15
        default: return "EW"    // 16
        }
    }

    static func renumberPBN(_ text: String, to boardNumber: Int) -> String {
        var result = text

        if let boardRegex = try? NSRegularExpression(
            pattern: #"(?i)^\s*\[Board\s*"\s*\d+\s*"\s*\]\s*$"#,
            options: [.anchorsMatchLines]
        ) {
            let fullRange = NSRange(result.startIndex..., in: result)
            if boardRegex.firstMatch(in: result, options: [], range: fullRange) != nil {
                result = boardRegex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: fullRange,
                    withTemplate: "[Board \"\(boardNumber)\"]"
                )
            } else {
                if let tagRegex = try? NSRegularExpression(pattern: #"(?m)^\s*\[[^\]]+\]\s*$"#) {
                    let fr = NSRange(result.startIndex..., in: result)
                    if let firstTag = tagRegex.firstMatch(in: result, options: [], range: fr) {
                        let ns = result as NSString
                        let insertIndex = firstTag.range.location + firstTag.range.length
                        let insertion = "\n[Board \"\(boardNumber)\"]"
                        result = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: insertion)
                    } else {
                        result = "[Board \"\(boardNumber)\"]\n" + result
                    }
                } else {
                    result = "[Board \"\(boardNumber)\"]\n" + result
                }
            }
        }

        let dealer = dealerForBoard(boardNumber)
        if let dealerRegex = try? NSRegularExpression(
            pattern: #"(?i)^\s*\[Dealer\s*"\s*[NESW]\s*"\s*\]\s*$"#,
            options: [.anchorsMatchLines]
        ) {
            let fullRange = NSRange(result.startIndex..., in: result)
            if dealerRegex.firstMatch(in: result, options: [], range: fullRange) != nil {
                result = dealerRegex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: fullRange,
                    withTemplate: "[Dealer \"\(dealer)\"]"
                )
            } else {
                if let boardLineRegex = try? NSRegularExpression(
                    pattern: #"(?i)^\s*\[Board\s*"\s*\d+\s*"\s*\]\s*$"#,
                    options: [.anchorsMatchLines]
                ) {
                    let r = NSRange(result.startIndex..., in: result)
                    if let boardMatch = boardLineRegex.firstMatch(in: result, options: [], range: r) {
                        let ns = result as NSString
                        let insertIndex = boardMatch.range.location + boardMatch.range.length
                        let insertion = "\n[Dealer \"\(dealer)\"]"
                        result = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: insertion)
                    } else if let tagRegex = try? NSRegularExpression(pattern: #"(?m)^\s*\[[^\]]+\]\s*$"#) {
                        let fr = NSRange(result.startIndex..., in: result)
                        if let firstTag = tagRegex.firstMatch(in: result, options: [], range: fr) {
                            let ns = result as NSString
                            let insertIndex = firstTag.range.location + firstTag.range.length
                            let insertion = "\n[Dealer \"\(dealer)\"]"
                            result = ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: insertion)
                        } else {
                            result = "[Dealer \"\(dealer)\"]\n" + result
                        }
                    } else {
                        result = "[Dealer \"\(dealer)\"]\n" + result
                    }
                }
            }
        }

        if let vulRegex = try? NSRegularExpression(
            pattern: #"(?i)^\s*\[Vulnerable\s*"\s*[^\"]*\s*"\s*\]\s*(?:\r?\n)?"#,
            options: [.anchorsMatchLines]
        ) {
            let fullRange = NSRange(result.startIndex..., in: result)
            result = vulRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: fullRange,
                withTemplate: ""
            )
        }

        let vul = vulnerabilityForBoard(boardNumber)
        let vulLine = "[Vulnerable \"\(vul)\"]"

        if let dealerLineRegex = try? NSRegularExpression(
            pattern: #"(?i)^\s*\[Dealer\s*"\s*[NESW]\s*"\s*\]\s*$"#,
            options: [.anchorsMatchLines]
        ) {
            let r = NSRange(result.startIndex..., in: result)
            if let dealerMatch = dealerLineRegex.firstMatch(in: result, options: [], range: r) {
                let ns = result as NSString
                let insertIndex = dealerMatch.range.location + dealerMatch.range.length
                return ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: "\n\(vulLine)")
            }
        }

        if let boardLineRegex = try? NSRegularExpression(
            pattern: #"(?i)^\s*\[Board\s*"\s*\d+\s*"\s*\]\s*$"#,
            options: [.anchorsMatchLines]
        ) {
            let r2 = NSRange(result.startIndex..., in: result)
            if let boardMatch = boardLineRegex.firstMatch(in: result, options: [], range: r2) {
                let ns = result as NSString
                let insertIndex = boardMatch.range.location + boardMatch.range.length
                return ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: "\n\(vulLine)")
            }
        }

        if let tagRegex = try? NSRegularExpression(pattern: #"(?m)^\s*\[[^\]]+\]\s*$"#) {
            let fr = NSRange(result.startIndex..., in: result)
            if let firstTag = tagRegex.firstMatch(in: result, options: [], range: fr) {
                let ns = result as NSString
                let insertIndex = firstTag.range.location + firstTag.range.length
                return ns.replacingCharacters(in: NSRange(location: insertIndex, length: 0), with: "\n\(vulLine)")
            }
        }

        return "\(vulLine)\n" + result
    }

    func renumberedPBNString(for url: URL) -> String? {
        guard url.pathExtension.lowercased() == "pbn" else { return nil }
        guard let board = intendedBoardNumber(for: url) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return Self.renumberPBN(text, to: board)
    }

    func renumberedPBNData(for url: URL) -> Data? {
        guard let s = renumberedPBNString(for: url) else { return nil }
        return s.data(using: .utf8)
    }
}
