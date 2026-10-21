import SwiftUI
import WidgetKit
import StickyCore

/// The box the widget opens: a text field to add a note (Return saves and closes) and, under it,
/// every note, which can be crossed out, edited, deleted, or dragged into a new order.
struct AddNoteView: View {
    /// Long enough for the panel to become key before the field asks for focus.
    private static let focusDelay: UInt64 = 350_000_000

    let onClose: () -> Void
    /// A note to open in edit mode (when the widget's edit field couldn't be placed).
    let editingID: UUID?
    @State private var text = ""
    @State private var board: StickyBoard
    @State private var errorText: String?
    @FocusState private var isFocused: Bool

    init(onClose: @escaping () -> Void, editing editingID: UUID? = nil) {
        self.onClose = onClose
        self.editingID = editingID
        do {
            _board = State(initialValue: try StickyStore().load())
            _errorText = State(initialValue: nil)
        } catch {
            _board = State(initialValue: .empty)
            _errorText = State(initialValue: "Couldn't read your notes: \(error.localizedDescription)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Notes", systemImage: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                CloseButton(action: onClose)
            }
            // Wraps onto more lines rather than scrolling sideways; Return still adds the note.
            TextField("Add a note, then press Return", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)
                .onSubmit(add)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if !board.notes.isEmpty {
                NoteListEditor(
                    notes: board.notes,
                    editing: editingID,
                    onToggle: { id in change { $0.toggling(id) } },
                    onRemove: { id in change { $0.removing(id) } },
                    onReorder: { ids in change { $0.ordering(ids) } },
                    onEdit: { id, text in change { $0.editing(id, text: text) } }
                )
            }
        }
        .task {
            // Opened to edit a note: that row's field takes the keyboard instead.
            guard editingID == nil else { return }
            try? await Task.sleep(nanoseconds: Self.focusDelay)
            isFocused = true
        }
    }

    private func add() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if change({ $0.adding(text) }) { onClose() }
    }

    /// Applies `edit` to the notes file (not just this view's copy, so a press on the widget
    /// meanwhile isn't lost), shows the result, and redraws the widget.
    @discardableResult
    private func change(_ edit: (StickyBoard) -> StickyBoard) -> Bool {
        do {
            board = try StickyStore().update(edit)
            errorText = nil
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            NSLog("Sticky Notes: could not save notes: \(error.localizedDescription)")
            errorText = "Couldn't save: \(error.localizedDescription)"
            return false
        }
    }
}

/// The round x in the box's corner. Closes the box like Escape, keeping a note being edited.
private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.quaternary.opacity(isHovered ? 1 : 0.6)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("Close")
        .accessibilityLabel("Close")
    }
}
