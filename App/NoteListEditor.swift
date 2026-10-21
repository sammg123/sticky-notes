import SwiftUI
import StickyCore

/// The notes under the text field in the box, each wrapped to as many lines as it needs. Drag a
/// row and the others slide out of its way; let go and it snaps into the nearest slot. The circle and x work as on the widget, and the
/// pencil turns a row into a text field: Return or a click elsewhere saves, Escape cancels, and
/// starting another row's edit saves this one first.
struct NoteListEditor: View {
    /// A one-line row; notes that wrap make theirs taller.
    static let rowHeight: CGFloat = 28
    /// Taller than this and the list scrolls instead of growing the box. A drag only reaches the
    /// rows in view (there's no autoscroll), so this is set high enough for a typical list.
    private static let maxListHeight = rowHeight * 14
    private static let snap = Animation.snappy(duration: 0.2)

    let notes: [StickyNote]
    let onToggle: (UUID) -> Void
    let onRemove: (UUID) -> Void
    let onReorder: ([UUID]) -> Void
    let onEdit: (UUID, String) -> Void

    @State private var drag: DragState?
    /// Each row's height as laid out, by note.
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @State private var editingID: UUID?
    /// The text in the row being edited; kept here so starting another edit can save it.
    @State private var draft: String

    init(
        notes: [StickyNote],
        editing: UUID? = nil,
        onToggle: @escaping (UUID) -> Void,
        onRemove: @escaping (UUID) -> Void,
        onReorder: @escaping ([UUID]) -> Void,
        onEdit: @escaping (UUID, String) -> Void
    ) {
        self.notes = notes
        self.onToggle = onToggle
        self.onRemove = onRemove
        self.onReorder = onReorder
        self.onEdit = onEdit
        _editingID = State(initialValue: editing)
        _draft = State(initialValue: notes.first { $0.id == editing }?.text ?? "")
    }

    private struct DragState: Equatable {
        let id: UUID
        let from: Int
        var translation: CGFloat
    }

    var body: some View {
        if heights.reduce(0, +) > Self.maxListHeight {
            ScrollView { rows }
                .frame(height: Self.maxListHeight)
        } else {
            rows
        }
    }

    /// The rows' heights in list order; one line's worth until a row has been measured.
    private var heights: [Double] {
        notes.map { Double(rowHeights[$0.id] ?? Self.rowHeight) }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                let isDragged = drag?.id == note.id
                let isEditing = editingID == note.id
                NoteEditRow(
                    note: note,
                    isLifted: isDragged,
                    isEditing: isEditing,
                    draft: $draft,
                    onToggle: onToggle,
                    onRemove: onRemove,
                    onStartEditing: { startEditing(note) },
                    onSubmit: { submit(note.id) },
                    onLeave: { save(note.id) },
                    onCancel: { if editingID == note.id { editingID = nil } }
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[note.id] = $0 }
                .offset(y: offset(of: index, isDragged: isDragged))
                .animation(isDragged ? nil : Self.snap, value: target)
                .zIndex(isDragged ? 1 : 0)
                // A row being edited keeps the mouse for selecting text.
                .gesture(dragGesture(id: note.id, index: index), including: isEditing ? .subviews : .all)
            }
        }
        .coordinateSpace(name: Self.space)
        // The notes changed under a drag (say, a cancelled one): drop the stale lift.
        .onChange(of: notes.map(\.id)) { drag = nil }
    }

    private func startEditing(_ note: StickyNote) {
        if let current = editingID, current != note.id { save(current) }
        draft = note.text
        editingID = note.id
    }

    /// Return: save, or beep if the note was emptied (saving that would wipe it).
    private func submit(_ id: UUID) {
        guard editingID == id else { return }
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSSound.beep()
            return
        }
        save(id)
    }

    /// Leaving the row (another edit, a click elsewhere, the box closing): keep what was typed.
    /// An emptied note is left as it was. Safe to call twice; only the open edit is saved.
    private func save(_ id: UUID) {
        guard editingID == id else { return }
        editingID = nil
        onEdit(id, draft)
    }

    private static let space = "noteList"

    /// The slot the dragged row would land in right now.
    private var target: Int? {
        drag.map {
            RowReorder.destination(from: $0.from, translation: $0.translation, heights: heights, spacing: 0)
        }
    }

    private func offset(of index: Int, isDragged: Bool) -> CGFloat {
        guard let drag, let target else { return 0 }
        if isDragged { return drag.translation }
        return RowReorder.shift(row: index, from: drag.from, to: target, heights: heights, spacing: 0)
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

/// Circle, note, pencil, (once crossed out) the x, and a grip that says the row can be dragged.
/// While editing, the note's text becomes a field.
private struct NoteEditRow: View {
    let note: StickyNote
    let isLifted: Bool
    let isEditing: Bool
    @Binding var draft: String
    let onToggle: (UUID) -> Void
    let onRemove: (UUID) -> Void
    let onStartEditing: () -> Void
    let onSubmit: () -> Void
    let onLeave: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFieldFocused: Bool

    /// Buttons are this square, and a row's first line this tall.
    private static let iconSide: CGFloat = 20
    private static let focusAttempts = 10
    private static let focusRetry: UInt64 = 50_000_000

    var body: some View {
        // Top-aligned: the buttons stay on the first line of a note that wraps.
        HStack(alignment: .top, spacing: 8) {
            iconButton(note.isCrossedOut ? "checkmark.circle.fill" : "circle", size: 14, weight: .regular,
                       label: note.isCrossedOut ? "Bring back \(note.text)" : "Cross out \(note.text)") { onToggle(note.id) }

            if isEditing {
                TextField("Note", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFieldFocused)
                    .onSubmit(onSubmit)
                    .onExitCommand(perform: onCancel)
                    // Only while it really has the keyboard does Escape cancel this edit instead
                    // of closing the box; a field that never got focus leaves Escape to the box.
                    .preference(key: ContentHandlesEscape.self, value: isFieldFocused)
                    // Focus moving elsewhere in the box (or the box closing) saves the edit.
                    .onChange(of: isFieldFocused) { wasFocused, isFocused in
                        if wasFocused && !isFocused { onLeave() }
                    }
                    .task {
                        // Asked again until it takes: a box that just opened, or another row's
                        // field still letting go, can drop the first request.
                        for _ in 0..<Self.focusAttempts {
                            isFieldFocused = true
                            do { try await Task.sleep(nanoseconds: Self.focusRetry) } catch { return }
                            if isFieldFocused { return }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 5).strokeBorder(.tertiary))
            } else {
                Text(note.text)
                    .font(.system(size: 13))
                    .strikethrough(note.isCrossedOut)
                    .foregroundStyle(note.isCrossedOut ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                iconButton("pencil", size: 12, weight: .medium, label: "Edit \(note.text)", action: onStartEditing)
            }

            if note.isCrossedOut && !isEditing {
                iconButton("xmark", size: 10, weight: .heavy, label: "Delete \(note.text)") { onRemove(note.id) }
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(height: Self.iconSide)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, (NoteListEditor.rowHeight - Self.iconSide) / 2)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isLifted ? AnyShapeStyle(.background) : AnyShapeStyle(.clear))
                .shadow(color: .black.opacity(isLifted ? 0.18 : 0), radius: 6, y: 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityHint("Drag to reorder")
    }

    private func iconButton(_ symbol: String, size: CGFloat, weight: Font.Weight, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(.secondary)
                .frame(width: Self.iconSide, height: Self.iconSide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
