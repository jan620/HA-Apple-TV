import SwiftUI

/// A slider driven by the remote's directional pad.
///
/// tvOS has no drag interaction to borrow, so the control takes focus and
/// translates left/right move commands into steps. Changes are committed after
/// a short pause so holding the pad does not flood Home Assistant with service
/// calls.
struct RemoteSlider: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var step: Double = 5
    var unit: String = ""
    var icon: String?
    let onCommit: (Double) -> Void

    @FocusState private var isFocused: Bool
    @State private var commitTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(isFocused ? Theme.accent : .secondary)
                }
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(HANumber.format(value))\(unit)")
                    .font(.headline.monospacedDigit())
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.cardBackgroundElevated)
                    Capsule()
                        .fill(isFocused ? Theme.accent : Theme.accent.opacity(0.6))
                        .frame(width: max(8, geometry.size.width * fraction))
                }
            }
            .frame(height: isFocused ? 24 : 16)
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            isFocused ? Theme.cardBackgroundElevated : Theme.cardBackground,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .focusable()
        .focused($isFocused)
        .onMoveCommand { direction in
            switch direction {
            case .left: adjust(by: -step)
            case .right: adjust(by: step)
            default: break
            }
        }
        .onDisappear { commitTask?.cancel() }
    }

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    private func adjust(by delta: Double) {
        let next = min(max(value + delta, range.lowerBound), range.upperBound)
        guard next != value else { return }
        value = next
        scheduleCommit(next)
    }

    private func scheduleCommit(_ newValue: Double) {
        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(nanoseconds: 400 * NSEC_PER_MSEC)
            guard !Task.isCancelled else { return }
            onCommit(newValue)
        }
    }
}

/// Plus/minus pair — far easier to hit precisely with a remote than a slider,
/// which is why thermostats use it.
struct RemoteStepper: View {
    let title: String
    let valueText: String
    var decreaseSymbol = "minus"
    var increaseSymbol = "plus"
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            Button(action: onDecrease) {
                Image(systemName: decreaseSymbol)
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.card)

            VStack(spacing: 4) {
                Text(valueText)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 200)

            Button(action: onIncrease) {
                Image(systemName: increaseSymbol)
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.card)
        }
    }
}

/// Horizontally scrolling choice list — used for HVAC modes, media sources,
/// fan presets and similar short option sets.
struct RemoteOptionPicker: View {
    let title: String
    let options: [String]
    let selection: String?
    var label: (String) -> String = { $0 }
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onSelect(option)
                        } label: {
                            Text(label(option))
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .foregroundStyle(option == selection ? Theme.accent : .primary)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
