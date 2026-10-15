import SwiftUI
import LEDSignCore

extension SignColor {
    var swiftUI: Color {
        Color(red: red ? 1 : 0, green: green ? 1 : 0, blue: blue ? 1 : 0)
    }
}

/// Draws a PixelFrame as LED dots. When `paint` is set, click/drag paints pixels.
/// Columns past `signWidth` are what scrolls into view; a divider marks the edge.
struct LEDPreview: View {
    let frame: PixelFrame
    let signWidth: Int
    var cell: CGFloat = 9
    var paint: ((Int, Int) -> Void)?

    var body: some View {
        let width = CGFloat(frame.width) * cell
        let height = CGFloat(frame.height) * cell
        Canvas { ctx, _ in
            ctx.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)), with: .color(.black))
            let inset = cell * 0.12
            for y in 0..<frame.height {
                for x in 0..<frame.width {
                    let c = frame[x, y]
                    let rect = CGRect(x: CGFloat(x) * cell + inset, y: CGFloat(y) * cell + inset,
                                      width: cell - inset * 2, height: cell - inset * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(c == .black ? Color(white: 0.13) : c.swiftUI))
                }
            }
            if frame.width > signWidth {
                let x = CGFloat(signWidth) * cell
                ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: height)) },
                           with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .gesture(paint.map { paint in
            DragGesture(minimumDistance: 0).onChanged { g in
                let x = Int(g.location.x / cell), y = Int(g.location.y / cell)
                if frame.contains(x: x, y: y) { paint(x, y) }
            }
        })
    }
}
