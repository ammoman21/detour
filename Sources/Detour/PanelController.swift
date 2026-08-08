import AppKit
import SwiftUI

// A Spotlight-style floating panel: borderless, translucent, non-activating
// (your reading app keeps focus ownership; the panel just takes key status for
// typing), joins all Spaces including full-screen apps, and is excluded from
// screen capture so a shared screen never shows your side-chat.
final class Panel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var onDismiss: (() -> Void)?

    // Esc
    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    override func resignKey() {
        super.resignKey()
        // Clicking back into whatever you were reading dismisses the panel.
        onDismiss?()
    }
}

@MainActor
final class PanelController {
    let viewModel = ChatViewModel()
    private let panel: Panel

    var isVisible: Bool { panel.isVisible }

    init(openSettings: @escaping () -> Void) {
        panel = Panel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 540),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.sharingType = .none
        panel.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let hosting = NSHostingView(
            rootView: ChatView(viewModel: viewModel, openSettings: openSettings)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: effectView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])

        panel.contentView = effectView
        panel.onDismiss = { [weak self] in self?.hide() }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        positionAtScreenEdge()
        viewModel.panelDidShow()
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .detourPanelDidShow, object: nil)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        viewModel.panelDidHide()
    }

    // Docked to the right edge of whichever screen the mouse is on — the
    // "margin note" position, next to whatever is being read.
    private func positionAtScreenEdge() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let size = panel.frame.size
        let margin: CGFloat = 16
        let origin = NSPoint(
            x: visible.maxX - size.width - margin,
            y: visible.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
