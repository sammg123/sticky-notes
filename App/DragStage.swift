import AppKit
import SwiftUI
import StickyCore

/// What the widget's rows look like mid-drag, drawn by the app right over them (the widget
/// can't animate a drag itself): the lifted note follows the pointer, the notes it passes slide
/// out of its way, and on release it snaps into its slot. It stays up until the widget has had
/// time to redraw in the new order, then fades.
@MainActor
final class DragStage {
    private static let snap = Animation.snappy(duration: 0.2)
    /// After a reorder: from the widget starting its redraw until it's on screen.
    private static let redrawLead: TimeInterval = 0.3
    /// After a reorder, if the widget never says it redrew.
    private static let longestHold: TimeInterval = 3
    private static let holdAfterNoChange: TimeInterval = 0.2
    private static let readyPoll: TimeInterval = 0.05
    private static let fade: TimeInterval = 0.15

    private let model = DragStageModel()
    private var panel: NSPanel?
    /// Bumped on every show, so a fade from an earlier drag can't hide a newer one.
    private var generation = 0

    /// Up and drawing (including the hold and fade after a drop).
    var isVisible: Bool { panel?.isVisible == true }
    /// Called once the stage has faded away.
    var onHidden: (() -> Void)?

    /// Draws `notes` over the widget at `frame` (screen coordinates, `WidgetLayout.rowsFrame`)
    /// and lifts the one at `lifted`.
    func show(notes: [StickyNote], lifting lifted: Int, frame: NSRect, level: NSWindow.Level) {
        generation += 1
        model.notes = notes
        model.lifted = nil
        model.pendingLift = lifted
        model.translation = 0
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.level = level
        panel.setFrame(frame, display: false)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        // Drawn flat first, matching the widget, then lifted, so the lift animates.
        DispatchQueue.main.async { [model] in
            MainActor.assumeIsolated {
                guard model.pendingLift == lifted else { return } // already dropped
                withAnimation(.easeOut(duration: 0.12)) { model.lifted = lifted }
            }
        }
    }

    /// Pointer movement since the press, in points, positive downward.
    func drag(by translation: CGFloat) {
        guard let lifted = model.lifted ?? model.pendingLift else { return }
        model.translation = RowReorder.clamped(translation: translation, from: lifted, rowHeight: WidgetLayout.rowPitch, count: model.notes.count)
    }

    /// The slot the lifted note would land in now.
    var target: Int? { model.target }

    /// Lets go: the note glides into `order`'s place for it (nil: back where it was), then the
    /// stage fades once `widgetCaughtUp` says the widget has started redrawing in that order.
    func drop(into order: [StickyNote]?, widgetCaughtUp: @escaping () -> Bool = { true }) {
        withAnimation(Self.snap) {
            if let order { model.notes = order }
            model.lifted = nil
            model.pendingLift = nil
            model.translation = 0
        }
        let current = generation
        guard order != nil else {
            fadeOut(generation: current, after: Self.holdAfterNoChange)
            return
        }
        waitForWidget(generation: current, deadline: Date().addingTimeInterval(Self.longestHold), ready: widgetCaughtUp)
    }

    private func waitForWidget(generation current: Int, deadline: Date, ready: @escaping () -> Bool) {
        guard current == generation else { return }
        if ready() {
            fadeOut(generation: current, after: Self.redrawLead)
        } else if Date() >= deadline {
            fadeOut(generation: current, after: 0)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyPoll) { [weak self] in
                MainActor.assumeIsolated { self?.waitForWidget(generation: current, deadline: deadline, ready: ready) }
            }
        }
    }

    private func fadeOut(generation current: Int, after delay: TimeInterval) {
        guard delay <= 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                MainActor.assumeIsolated { self?.fadeOut(generation: current, after: 0) }
            }
            return
        }
        guard current == generation, let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fade
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, current == self.generation else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                self.onHidden?()
            }
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        let host = NSHostingView(rootView: DragStageView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }
}

@MainActor
@Observable
final class DragStageModel {
    var notes: [StickyNote] = []
    /// The row being dragged, once it has visibly lifted.
    var lifted: Int?
    /// Set before the lift animates in, so early pointer movement isn't lost.
    var pendingLift: Int?
    var translation: CGFloat = 0

    var target: Int? {
        (lifted ?? pendingLift).map {
            RowReorder.destination(from: $0, translation: translation, rowHeight: WidgetLayout.rowPitch, count: notes.count)
        }
    }
}

/// The widget's rows on its paper, laid out with the same numbers the widget uses.
struct DragStageView: View {
    let model: DragStageModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Covers the widget's own rows while they're being rearranged.
            Rectangle().fill(StickyPalette.paper)
            ForEach(Array(model.notes.enumerated()), id: \.element.id) { index, note in
                let isLifted = model.lifted == index
                StageLine(note: note, isLifted: isLifted)
                    .offset(y: WidgetLayout.stageMargin.height + CGFloat(index) * WidgetLayout.rowPitch + offset(of: index))
                    .zIndex(isLifted ? 1 : 0)
                    .animation(isLifted ? nil : .snappy(duration: 0.2), value: model.target)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func offset(of index: Int) -> CGFloat {
        guard let lifted = model.lifted, let target = model.target else { return 0 }
        if index == lifted { return model.translation }
        return RowReorder.shift(row: index, from: lifted, to: target, rowHeight: WidgetLayout.rowPitch)
    }
}

/// One note's line as the widget draws it; lifted, it gets a card under it and a soft shadow.
private struct StageLine: View {
    let note: StickyNote
    let isLifted: Bool

    var body: some View {
        HStack(spacing: WidgetLayout.gap) {
            NoteCircleMark(note: note, ink: StickyPalette.ink)
            NoteTextLabel(note: note, ink: StickyPalette.ink)
            if note.isCrossedOut { NoteDeleteMark(ink: StickyPalette.ink) }
        }
        .frame(height: WidgetLayout.rowHeight)
        .padding(.horizontal, WidgetLayout.stageMargin.width)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(StickyPalette.paper)
                .shadow(color: .black.opacity(isLifted ? 0.22 : 0), radius: 5, y: 2)
        }
        .scaleEffect(isLifted ? 1.02 : 1)
    }
}
