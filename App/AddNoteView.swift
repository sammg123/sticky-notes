import SwiftUI
import WidgetKit
import StickyCore

/// One text field. Return saves the note and closes; Escape or a click elsewhere just closes.
struct AddNoteView: View {
    /// Long enough for the panel to become key before the field asks for focus.
    private static let focusDelay: UInt64 = 350_000_000

    let onClose: () -> Void
    @State private var text = ""
    @State private var errorText: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("New sticky note", systemImage: "note.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Write a note, then press Return", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)
                .onSubmit(save)
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: Self.focusDelay)
            isFocused = true
        }
    }

    private func save() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try StickyStore().update { $0.adding(text) }
            WidgetCenter.shared.reloadAllTimelines()
            onClose()
        } catch {
            NSLog("Sticky Notes: could not save a note: \(error.localizedDescription)")
            errorText = "Couldn't save the note: \(error.localizedDescription)"
        }
    }
}
