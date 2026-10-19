import SwiftUI
import StickyCore

/// The notes under the text field in the box. Drag a row and the others slide out of its way;
/// let go and it snaps into the nearest slot. The circle and x work as on the widget.
struct NoteListEditor: View {
    static let rowHeight: CGFloat = 28
    /// More than this and the list scrolls instead of growing the box. A drag only reaches the
    /// rows in view (there's no autoscroll), so this is set high enough for a typical list.
    private static let maxVisibleRows = 14
    private static let snap = Animation.snappy(duration: 0.2)

    let notes: [StickyNote]
    let onToggle: (UUID) -> Void
    let onRemove: (UUID) -> Void
    let onReorder: ([UUID]) -> Void

    @State private var drag: DragState?

    private struct DragState: Equatable {
        let id: UUID
        let from: Int
        var translation: CGFloat
    }

    var body: some View {
        if notes.count > Self.maxVisibleRows {
            ScrollView { rows }
                .frame(height: Self.rowHeight * CGFloat(Self.maxVisibleRows))
        } else {
            rows
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                let isDragged = drag?.id == note.id
                NoteEditRow(note: note, isLifted: isDragged, onToggle: onToggle, onRemove: onRemove)
                    .offset(y: offset(of: index, isDragged: isDragged))
                    .animation(isDragged ? nil : Self.snap, value: target)
                    .zIndex(isDragged ? 1 : 0)
                    .gesture(dragGesture(id: note.id, index: index))
            }
        }
        .coordinateSpace(name: Self.space)
        // The notes changed under a drag (say, a cancelled one): drop the stale lift.
        .onChange(of: notes.map(\.id)) { drag = nil }
    }

    private static let space = "noteList"

    /// The slot the dragged row would land in right now.
    private var target: Int? {
        drag.map {
            RowReorder.destination(from: $0.from, translation: $0.translation, rowHeight: Self.rowHeight, count: notes.count)
        }
    }

    private func offset(of index: Int, isDragged: Bool) -> CGFloat {
        guard let drag, let target else { return 0 }
        if isDragged { return drag.translation }
        return RowReorder.shift(row: index, from: drag.from, to: target, rowHeight: Self.rowHeight)
    }

    private func dragGesture(id: UUID, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                // A drag that ended without onEnded (cancelled) must not lend its start to this one.
                let from = drag.flatMap { $0.id == id ? $0.from : nil } ?? index
                drag = DragState(id: id, from: from, translation: value.translation.height)
            }
            .onEnded { _ in
                guard let drag, let target else { return }
                let order = RowReorder.moved(notes.map(\.id), from: drag.from, to: target)
                // One transaction: the list takes its new order and the row lets go of the
                // pointer together, so the row glides from where it was dropped into its slot.
                withAnimation(Self.snap) {
                    self.drag = nil
                    if order != notes.map(\.id) { onReorder(order) }
                }
            }
    }
}

/// Circle, note, and (once crossed out) the x, plus a grip that says the row can be dragged.
private struct NoteEditRow: View {
    let note: StickyNote
    let isLifted: Bool
    let onToggle: (UUID) -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { onToggle(note.id) } label: {
                Image(systemName: note.isCrossedOut ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isCrossedOut ? "Bring back \(note.text)" : "Cross out \(note.text)")

            Text(note.text)
                .font(.system(size: 13))
                .strikethrough(note.isCrossedOut)
                .foregroundStyle(note.isCrossedOut ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if note.isCrossedOut {
                Button { onRemove(note.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(note.text)")
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .frame(height: NoteListEditor.rowHeight)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isLifted ? AnyShapeStyle(.background) : AnyShapeStyle(.clear))
                .shadow(color: .black.opacity(isLifted ? 0.18 : 0), radius: 6, y: 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityHint("Drag to reorder")
    }
}
