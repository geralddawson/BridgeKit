import SwiftUI


struct PerCornerRoundedRectangle: Shape {
    var topLeading: CGFloat
    var topTrailing: CGFloat
    var bottomLeading: CGFloat
    var bottomTrailing: CGFloat

    func path(in rect: CGRect) -> Path {
        let tl = max(0, min(min(rect.width, rect.height) / 2, topLeading))
        let tr = max(0, min(min(rect.width, rect.height) / 2, topTrailing))
        let bl = max(0, min(min(rect.width, rect.height) / 2, bottomLeading))
        let br = max(0, min(min(rect.width, rect.height) / 2, bottomTrailing))

        var path = Path()
        let w = rect.width
        let h = rect.height

        // Start at top-left, after the corner radius
        path.move(to: CGPoint(x: tl, y: 0))

        // Top edge to top-right
        path.addLine(to: CGPoint(x: w - tr, y: 0))
        // Top-right corner
        if tr > 0 {
            path.addQuadCurve(to: CGPoint(x: w, y: tr), control: CGPoint(x: w, y: 0))
        } else {
            path.addLine(to: CGPoint(x: w, y: 0))
        }

        // Right edge to bottom-right
        path.addLine(to: CGPoint(x: w, y: h - br))
        // Bottom-right corner
        if br > 0 {
            path.addQuadCurve(to: CGPoint(x: w - br, y: h), control: CGPoint(x: w, y: h))
        } else {
            path.addLine(to: CGPoint(x: w, y: h))
        }

        // Bottom edge to bottom-left
        path.addLine(to: CGPoint(x: bl, y: h))
        // Bottom-left corner
        if bl > 0 {
            path.addQuadCurve(to: CGPoint(x: 0, y: h - bl), control: CGPoint(x: 0, y: h))
        } else {
            path.addLine(to: CGPoint(x: 0, y: h))
        }

        // Left edge to top-left
        path.addLine(to: CGPoint(x: 0, y: tl))
        // Top-left corner
        if tl > 0 {
            path.addQuadCurve(to: CGPoint(x: tl, y: 0), control: CGPoint(x: 0, y: 0))
        } else {
            path.addLine(to: CGPoint(x: 0, y: 0))
        }

        path.closeSubpath()
        return path
    }
}

// A SwiftUI-drawn playing card that shows only a top-left rank/suit index with spacing.

struct PlayingCardView: View {
    let rankCode: String   // "A","K","Q","J","T","9",...,"2"
    let suit: DisplaySuit

    // Card fills its frame; width and height can be adjusted independently.

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let corner = min(w, h) * 0.22
            
       ZStack {
                PerCornerRoundedRectangle(topLeading: corner, topTrailing: 0, bottomLeading: 0, bottomTrailing: corner)
                    .fill(Color.white)

                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(PerCornerRoundedRectangle(topLeading: corner, topTrailing: 0, bottomLeading: 0, bottomTrailing: corner))

                PerCornerRoundedRectangle(topLeading: corner, topTrailing: 0, bottomLeading: 0, bottomTrailing: corner)
                    .stroke(Color.black, lineWidth: 1)

                content(foreground: suit.isRed ? Color(red: 0.75, green: 0.0, blue: 0.12) : Color.black, width: w, height: h)
            }
        }
        .drawingGroup() // crisp in snapshots
    }

    private func content(foreground: Color, width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            cornerIndex(foreground: foreground, width: w)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, w * 0.07)
                .padding(.leading, w * 0.07)
            
            Text("GD")
                .font(Font.custom("Savoye LET", size: 16, relativeTo: .title3))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, w * 0.07)
                .padding(.bottom, h * 0.03)
        }
    }

    private var displayRank: String {
        return rankCode.uppercased()
    }

    private func cornerIndex(foreground: Color, width w: CGFloat) -> some View {
        let rankSize = w * 0.40
        let suitSize = w * 0.36
        return VStack(alignment: .leading, spacing: max(2, w * 0.022)) {
            Text(displayRank)
                .font(.system(size: rankSize, weight: .regular, design: .rounded))
                .foregroundStyle(Color.black)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(suit.symbol)
                .font(.system(size: suitSize, weight: .regular, design: .default))
                .foregroundStyle(foreground)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
}

#Preview("PlayingCardView") {
    VStack(spacing: 16) {
        HStack {
            PlayingCardView(rankCode: "A", suit: .spades).frame(width: 120, height: 168)
            PlayingCardView(rankCode: "K", suit: .hearts).frame(width: 120, height: 168)
            PlayingCardView(rankCode: "Q", suit: .diamonds).frame(width: 120, height: 168)
            PlayingCardView(rankCode: "J", suit: .clubs).frame(width: 120, height: 168)
        }
        HStack {
            PlayingCardView(rankCode: "T", suit: .spades).frame(width: 120, height: 168)
            PlayingCardView(rankCode: "9", suit: .hearts).frame(width: 120, height: 168)
            PlayingCardView(rankCode: "5", suit: .diamonds).frame(width: 120, height: 168)
            PlayingCardView(rankCode: "2", suit: .clubs).frame(width: 120, height: 168)
        }
    }
    .padding()
}

