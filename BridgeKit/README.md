# BridgeCompose (BridgeTeacherHandCompose)
Bridge Hand Composer is a macOS SwiftUI app that helps bridge teachers compose, preview, and organize duplicate bridge deals. Deals are saved in Portable Bridge Notation (PBN), with optional notes and a snapshot image for each board. A built‑in Library lets you file boards into your own categories and assemble aggregated session files. 

## Features
- Compose N/E/S/W hands quickly with a compact suit/rank grid
- Auto‑fill: when 39 cards are placed, the remaining 13 are assigned to the last hand
- Per‑board PBN export with standard Dealer/Vulnerability rotation
- Instant visual preview with HCP badges and high‑contrast layout
- Record notes and save a snapshot image (macOS rendering)
- File boards to Library categories and build aggregated PBN sessions

## Requirements
- Xcode 15+ (tested with modern SwiftUI on macOS)
- macOS target (primary experience). iOS code paths are present, but macOS is the focus.
- No third‑party dependencies

## Getting Started
1. Clone this repository.
2. Open the project in Xcode.
3. Select the macOS scheme and Run.
4. (Optional) Show the Onboarding to learn the workflow.

## Typical Workflow
1. Click New Session → enter a name → Save (creates a session folder).
2. Select a seat (N/E/S/W) and tap card ranks to add.
3. When 39 cards are placed, the last 13 are auto‑filled into the remaining hand.
4. A full deal (52 cards) is saved to PBN and the board counter advances.
5. Open Preview to review the layout, type notes, save a snapshot, or file the board into the Library.
6. Repeat for the next board.

## Where Your Data Is Stored
All user data is written to your Documents folder. Exact paths may vary if the app is sandboxed (e.g., under the app container’s Documents).

- Sessions (per session name):
  - Documents/BridgeSessions/<SessionName>/
  - Board files saved as:
    - Board <n>.pbn
    - Board <n>.notes.txt (optional, when you record notes)
    - Board <n>.jpg (optional snapshot on macOS)
  - Aggregated session PBN (when preview aggregation runs):
    - Documents/BridgeSessions/<SessionName>.pbn

- Library & Categories (user‑defined and per‑device):
  - Documents/BridgeLibrary/categories.json (list of categories)
  - Documents/BridgeLibrary/Categories/<CategoryName>/ (filed boards)
  - When filing a board to a category, the app copies available artifacts:
    - <Session>-Board-<n>.pbn
    - <Session>-Board-<n>.notes.txt
    - <Session>-Board-<n>.jpg

Note: Categories are local to each user/device. They are not part of the repository unless you explicitly add them.

## PBN Output
Each board’s PBN includes standard headers and the Deal string. Example:
[Event "Gez1"]
[Board "1"]
[Dealer "N"]
[Vulnerable "None"]
[Deal "N:6.AK3.A73.QJT986 AJ73.98.KJ65.K74 Q54.J7654.T984.5 KT982.QT2.Q2.A32"]

