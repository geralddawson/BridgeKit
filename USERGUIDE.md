# BridgeCompose (BridgeTeacherHandCompose)
Bridge Hand Composer is a macOS SwiftUI app that helps bridge teachers compose, preview, and organise duplicate bridge deals. Deals are saved in Portable Bridge Notation (PBN), with optional notes and a snapshot image for each board. A built‑in Library lets you file boards into your own categories and assemble aggregated session files. 

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

## Aggregating Library Boards into a New Session

You can build a complete session file by aggregating individual boards you previously filed into the Library. This is useful when you want to teach from a curated set of boards across one or more categories.

### What aggregation produces
- A single PBN file that concatenates the selected boards
- Boards are renumbered starting at 1 in the order you choose
- The `Event` header is set to the session name you provide
- Only PBN content is merged; notes and snapshots remain in their original Library folders
- The resulting file is saved to: `Documents/BridgeSessions/<SessionName>.pbn`

### Steps (macOS)
1. Open the Library from the app’s main toolbar.
2. In the sidebar, choose a category that contains the boards you want.
3. Select the boards (`.pbn` files) to include:
   - Command-click to add/remove individual boards
   - Shift-click to select a range
4. Click the Library toolbar action to preview your selection ("Preview Selection").
   - In the preview, the left pane lists the selected files; click a file to preview its content.
   - Use the Remove button to exclude a file from the selection, then Close to return to the Library.
5. When you’re happy with the selection, use the Library toolbar action to aggregate ("Aggregate" or "Build Session").
   - Enter a session name when prompted. The app writes the aggregated PBN to `Documents/BridgeSessions/<SessionName>.pbn`.

### Ordering and renumbering
- The order shown in the preview list determines board numbering in the aggregated file (first = Board 1, second = Board 2, etc.).
- To change the order, remove an item from the selection and re-add it in the desired position; you can also clear and reselect in the correct sequence.
- Each board’s `Dealer` and `Vulnerable` headers remain as they are in the source PBN. The app does not recompute them during aggregation.

### Tips & troubleshooting
- Make sure only `.pbn` files are selected; non-PBN files are ignored.
- If the aggregation action is disabled, ensure you have at least one `.pbn` selected.
- If a board looks wrong, use the preview to verify and remove it before aggregating.

### Example (snippet)
