import SwiftUI

struct FramingGuide: View {
    var body: some View {
        GeometryReader { geometry in
            let frame = FramingGuideLayout.frame(in: geometry.size)
            let center = CGPoint(x: frame.midX, y: frame.midY)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .frame(width: frame.width, height: frame.height)
                    .position(center)

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: frame.minY))
                    path.addLine(to: CGPoint(x: center.x, y: frame.maxY))
                }
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))

                Path { path in
                    path.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                    path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                    path.move(to: CGPoint(x: center.x - 12, y: center.y))
                    path.addLine(to: CGPoint(x: center.x + 12, y: center.y))
                    path.move(to: CGPoint(x: center.x, y: center.y - 12))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + 12))
                }
                .stroke(.cyan, style: StrokeStyle(lineWidth: 2))
            }
            .shadow(color: .black, radius: 3)
        }
    }
}

enum FramingGuideLayout {
    static func frame(in size: CGSize) -> CGRect {
        CGRect(
            x: size.width * 0.08,
            y: size.height * 0.08,
            width: size.width * 0.84,
            height: size.height * 0.84
        )
    }
}
