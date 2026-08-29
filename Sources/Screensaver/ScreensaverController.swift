import Combine
import SwiftUI
import UIKit

/// Decides when the ambient screen takes over.
///
/// tvOS offers no way to extend or draw on top of the system screen saver —
/// there is no third-party screen saver API on the platform. What an app *can*
/// do is suppress the system saver while it is frontmost and present its own
/// idle screen instead, which is what this does.
@MainActor
final class ScreensaverController: ObservableObject {
    @Published private(set) var isActive = false
    /// When the ambient screen is due to appear, so the settings screen can show
    /// the remaining time. `nil` means no countdown is running.
    @Published private(set) var countdownEndsAt: Date?

    private var idleTask: Task<Void, Never>?
    private var delay: TimeInterval = 300
    private var isEnabled = false
    /// A manual start would otherwise be undone by the very button press that
    /// triggered it: the activity detector sees that press too.
    private var ignoreActivityUntil: Date?

    /// Applies the user's settings and (re)starts the idle countdown.
    func configure(enabled: Bool, delay: TimeInterval) {
        isEnabled = enabled
        self.delay = delay

        // Without this the Apple TV's own screen saver would appear first and
        // ours would never get a turn.
        UIApplication.shared.isIdleTimerDisabled = enabled

        if enabled {
            restartCountdown()
        } else {
            cancelCountdown()
            isActive = false
        }
    }

    /// Shows the ambient screen right now, regardless of the countdown — the
    /// only way to check what it looks like without waiting out the delay.
    func startNow() {
        cancelCountdown()
        // The press that invoked this reaches the activity detector as well;
        // without a short grace period it would close the screen immediately.
        ignoreActivityUntil = Date().addingTimeInterval(1.5)
        // A preview with the screen saver switched off still has to outlast the
        // Apple TV's own.
        UIApplication.shared.isIdleTimerDisabled = true
        withAnimation(.easeIn(duration: 0.5)) {
            isActive = true
        }
    }

    /// Any remote input at all: wakes the ambient screen, or pushes the
    /// countdown back if it has not started yet.
    func noteActivity() {
        if let until = ignoreActivityUntil {
            guard Date() >= until else { return }
            ignoreActivityUntil = nil
        }

        if isActive {
            withAnimation(.easeOut(duration: 0.35)) {
                isActive = false
            }
        }
        guard isEnabled else {
            // Nothing left to suppress once a manual preview is over.
            UIApplication.shared.isIdleTimerDisabled = false
            return
        }
        restartCountdown()
    }

    func stop() {
        cancelCountdown()
        isActive = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func cancelCountdown() {
        idleTask?.cancel()
        idleTask = nil
        countdownEndsAt = nil
    }

    private func restartCountdown() {
        idleTask?.cancel()
        countdownEndsAt = Date().addingTimeInterval(delay)
        idleTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.delay * Double(NSEC_PER_SEC)))
            guard !Task.isCancelled, self.isEnabled else { return }
            self.countdownEndsAt = nil
            withAnimation(.easeIn(duration: 0.8)) {
                self.isActive = true
            }
        }
    }
}

/// Reports every remote press and touch without consuming it.
///
/// SwiftUI has no app-wide "user did something" signal, so a gesture
/// recognizer is attached to the window. It reports in `touchesBegan` /
/// `pressesBegan` and then fails immediately, which means it observes the
/// event stream without ever winning a gesture or swallowing input.
private final class ActivityRecognizer: UIGestureRecognizer {
    var onActivity: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        allowedPressTypes = [
            UIPress.PressType.select, .menu, .playPause,
            .upArrow, .downArrow, .leftArrow, .rightArrow,
        ].map { NSNumber(value: $0.rawValue) }
    }

    @objc func handle() {}

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        report()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        super.pressesBegan(presses, with: event)
        report()
    }

    private func report() {
        onActivity?()
        // Failing keeps the recognizer out of the way; it re-arms once the
        // current gesture sequence ends.
        state = .failed
    }
}

private final class ActivityTrackingView: UIView {
    var onActivity: (() -> Void)?
    private var recognizer: ActivityRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window, recognizer == nil else { return }

        let recognizer = ActivityRecognizer(target: nil, action: nil)
        recognizer.addTarget(recognizer, action: #selector(ActivityRecognizer.handle))
        recognizer.onActivity = { [weak self] in self?.onActivity?() }
        window.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
    }
}

/// Invisible view that feeds remote activity to the controller.
struct IdleActivityDetector: UIViewRepresentable {
    let onActivity: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = ActivityTrackingView()
        view.isUserInteractionEnabled = false
        view.onActivity = onActivity
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? ActivityTrackingView)?.onActivity = onActivity
    }
}
