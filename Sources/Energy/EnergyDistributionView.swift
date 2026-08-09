import SwiftUI

/// Sankey-style diagram of where energy came from and where it went.
///
/// Drawn directly rather than with a chart library: the bands need a width
/// proportional to their value and a node's height has to equal the sum of the
/// bands touching it, which no standard chart type expresses.
struct EnergyDistributionView: View {
    let links: [EnergyFlowLink]

    private let barWidth: CGFloat = 22
    private let nodeGap: CGFloat = 26
    private let labelInset: CGFloat = 14

    var body: some View {
        Canvas { context, size in
            let layout = Layout(
                links: links,
                size: size,
                barWidth: barWidth,
                nodeGap: nodeGap
            )
            guard layout.isDrawable else { return }

            drawBands(context: context, layout: layout, size: size)
            drawNodes(context: context, layout: layout, size: size)
        }
        .frame(height: 340)
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private func drawBands(context: GraphicsContext, layout: Layout, size: CGSize) {
        let leftEdge = barWidth
        let rightEdge = size.width - barWidth
        let midX = (leftEdge + rightEdge) / 2

        // Consumed height at each end, so bands stack instead of overlapping.
        var sourceOffset: [EnergyNode: CGFloat] = [:]
        var targetOffset: [EnergyNode: CGFloat] = [:]

        for link in links.sorted(by: { $0.value > $1.value }) {
            guard let source = layout.sourceFrames[link.source],
                  let target = layout.targetFrames[link.target]
            else { continue }

            let thickness = link.value * layout.scale
            let startY = source.origin + (sourceOffset[link.source] ?? 0)
            let endY = target.origin + (targetOffset[link.target] ?? 0)
            sourceOffset[link.source, default: 0] += thickness
            targetOffset[link.target, default: 0] += thickness

            var band = Path()
            band.move(to: CGPoint(x: leftEdge, y: startY))
            band.addCurve(
                to: CGPoint(x: rightEdge, y: endY),
                control1: CGPoint(x: midX, y: startY),
                control2: CGPoint(x: midX, y: endY)
            )
            band.addLine(to: CGPoint(x: rightEdge, y: endY + thickness))
            band.addCurve(
                to: CGPoint(x: leftEdge, y: startY + thickness),
                control1: CGPoint(x: midX, y: endY + thickness),
                control2: CGPoint(x: midX, y: startY + thickness)
            )
            band.closeSubpath()

            context.fill(band, with: .color(Self.color(for: link.source).opacity(0.45)))
        }
    }

    private func drawNodes(context: GraphicsContext, layout: Layout, size: CGSize) {
        for (node, frame) in layout.sourceFrames {
            let rect = CGRect(x: 0, y: frame.origin, width: barWidth, height: frame.height)
            context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(Self.color(for: node)))
            context.draw(
                label(for: node, value: frame.value),
                at: CGPoint(x: barWidth + labelInset, y: frame.origin + frame.height / 2),
                anchor: .leading
            )
        }

        for (node, frame) in layout.targetFrames {
            let rect = CGRect(
                x: size.width - barWidth,
                y: frame.origin,
                width: barWidth,
                height: frame.height
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(Self.color(for: node)))
            context.draw(
                label(for: node, value: frame.value),
                at: CGPoint(x: size.width - barWidth - labelInset, y: frame.origin + frame.height / 2),
                anchor: .trailing
            )
        }
    }

    private func label(for node: EnergyNode, value: Double) -> Text {
        Text("\(node.title)  \(HANumber.format(value, maximumFractionDigits: 1)) kWh")
            .font(.caption)
            .foregroundStyle(.primary)
    }

    static func color(for node: EnergyNode) -> Color {
        switch node {
        case .solar: return .yellow
        case .grid: return .orange
        case .batteryOut, .batteryIn: return .teal
        case .home: return Theme.accent
        case .gridExport: return .green
        }
    }

    // MARK: Layout

    /// Vertical placement of every node, sized proportionally to its throughput.
    private struct Layout {
        struct Frame {
            let origin: CGFloat
            let height: CGFloat
            let value: Double
        }

        var sourceFrames: [EnergyNode: Frame] = [:]
        var targetFrames: [EnergyNode: Frame] = [:]
        var scale: CGFloat = 0

        var isDrawable: Bool { scale > 0 && !sourceFrames.isEmpty && !targetFrames.isEmpty }

        init(links: [EnergyFlowLink], size: CGSize, barWidth: CGFloat, nodeGap: CGFloat) {
            let sources = EnergyNode.sources.compactMap { node -> (EnergyNode, Double)? in
                let value = links.filter { $0.source == node }.reduce(0) { $0 + $1.value }
                return value > 0 ? (node, value) : nil
            }
            let targets = EnergyNode.sinks.compactMap { node -> (EnergyNode, Double)? in
                let value = links.filter { $0.target == node }.reduce(0) { $0 + $1.value }
                return value > 0 ? (node, value) : nil
            }

            guard !sources.isEmpty, !targets.isEmpty else { return }

            let total = max(
                sources.reduce(0) { $0 + $1.1 },
                targets.reduce(0) { $0 + $1.1 }
            )
            guard total > 0 else { return }

            // Both columns share one scale so a band keeps its thickness across
            // the diagram; the taller column decides how much height is left
            // once the gaps are subtracted.
            let gapCount = CGFloat(max(sources.count, targets.count) - 1)
            let usableHeight = max(size.height - nodeGap * gapCount, 1)
            scale = usableHeight / total

            var y: CGFloat = 0
            for (node, value) in sources {
                let height = value * scale
                sourceFrames[node] = Frame(origin: y, height: height, value: value)
                y += height + nodeGap
            }

            y = 0
            for (node, value) in targets {
                let height = value * scale
                targetFrames[node] = Frame(origin: y, height: height, value: value)
                y += height + nodeGap
            }
        }
    }
}
