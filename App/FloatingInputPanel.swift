import AppKit
import SwiftUI

/// The floating box the widget opens to take typing.
/// Spotlight-style: it floats in the upper part of the screen under the pointer, takes the
/// keyboard, and closes after the content calls `close`, on Escape, or on a click elsewhere.
@MainActor
final class FloatingInputPanel: NSObject, NSWindowDelegate {
    /// Fraction of the screen height between the top of the visible area and the box.
    private static let topOffsetFraction: CGFloat = 0.2
    static let width: CGFloat = 420

    private var panel: NSPanel?
    /// The app that was in front when the box opened; it gets the keyboard back afterwards.
    private var previousApp: NSRunningApplication?
    /// The box's latest reported height; queued resizes all apply this, so a stale one is harmless.
    private var targetHeight: CGFloat = 0

    /// Opens the box with fresh content, or just brings it forward (keeping what is typed) if it
    /// is already open. `content` gets the close action to call once its job is done.
    func show<Content: View>(@ViewBuilder content: (_ close: @escaping () -> Void) -> Content) {
        if let panel, panel.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let close: () -> Void = { [weak self] in self?.dismiss() }
        let root = PanelChrome(
            onClose: close,
            onHeightChange: { [weak self] in self?.fitHeight($0) },
            content: content(close)
        )
        let host = NSHostingView(rootView: root)
        // Measured before it joins the window, so the hidden titlebar's inset isn't counted.
        targetHeight = host.fittingSize.height
        // From here the panel follows the box's height itself (see `fitHeight`). Letting SwiftUI
        // size the window from inside AppKit's constraint pass looped that pass until AppKit
        // threw, which crashed Due mid-typing whenever the box grew or shrank by a point.
        host.sizingOptions = []
        panel.contentView = host
        panel.setContentSize(NSSize(width: Self.width, height: targetHeight))
        place(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Resizes to the box's new height on the next run loop turn, outside any layout pass,
    /// keeping the top edge where it is.
    private func fitHeight(_ height: CGFloat) {
        targetHeight = height
        DispatchQueue.main.async { [weak self] in self?.applyTargetHeight() }
    }

    private func applyTargetHeight() {
        guard let panel, targetHeight > 0 else { return }
        let content = panel.contentRect(forFrameRect: panel.frame)
        guard abs(content.height - targetHeight) > 0.5 else { return }
        var frame = panel.frame
        let top = frame.maxY
        frame.size.height += targetHeight - content.height
        frame.origin.y = top - frame.size.height
        panel.setFrame(frame, display: true)
    }

    /// Escape or a finished entry: close and hand the keyboard back to where the user was.
    private func dismiss() {
        panel?.orderOut(nil)
        previousApp?.activate()
        previousApp = nil
    }

    /// Clicking elsewhere already moved focus, so only hide.
    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
        previousApp = nil
    }

    private func makePanel() -> NSPanel {
        let panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        return panel
    }

    private func place(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let visible = (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.visibleFrame else {
            panel.center()
            return
        }
        let top = visible.maxY - visible.height * Self.topOffsetFraction
        panel.setFrameTopLeftPoint(NSPoint(x: visible.midX - panel.frame.width / 2, y: top))
    }
}

/// Borderless-looking panels still have to opt in to taking the keyboard.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Padding, width, height reporting, and Escape around the box content.
private struct PanelChrome<Content: View>: View {
    let onClose: () -> Void
    let onHeightChange: (CGFloat) -> Void
    let content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(width: FloatingInputPanel.width)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeightChange($0) }
            // Pinned to the top while the panel catches up with a new height.
            .frame(maxHeight: .infinity, alignment: .top)
            // The titlebar is transparent and empty; without this SwiftUI adds its height on top.
            .ignoresSafeArea()
            .background(escapeButton)
    }

    private var escapeButton: some View {
        Button("", action: onClose)
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}
