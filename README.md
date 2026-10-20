# Sticky Notes

A desktop widget for quick notes on macOS. Nothing else. The widget is called Notes.

- **Add:** click the widget (the + in its corner) and a small box opens. Type the note and press Return. Escape, the x in its corner, or a click elsewhere closes the box without saving.
- **Cross out:** click the circle next to a note; it turns into a checkmark. Click it again to bring the note back.
- **Remove:** a crossed-out note gets an x at the end of its line; click it to delete the note.
- **Edit:** click a note's text on the widget and an edit field appears right over that line. Return saves, Escape cancels, clicking elsewhere saves. (Widgets can't hold text fields, so the app lays a borderless field exactly over the line.) In the box, the pencil next to a note turns it into a field: Return or clicking elsewhere saves, Escape cancels just that edit. An emptied note isn't saved; Return beeps instead.
- **Reorder:** press and hold a note's text on the widget (or just start dragging it), move it up or down, and let go; the others slide out of the way and it snaps into place. A quick click on the text still edits it. The box the widget opens lists every note too, and they drag the same way there.

Newest notes sit at the top. Small and medium widgets show 4 rows and large shows 11. When the notes don't all fit, the last row tells you how many are hidden.

## Install

Needs macOS 14+, Xcode, and XcodeGen (`brew install xcodegen`).

```sh
./build.sh          # builds and installs ~/Applications/Sticky Notes.app
./build.sh --test   # runs the unit tests first
```

Then right-click the desktop, choose **Edit Widgets**, search for **Sticky Notes**, and drag the Notes widget onto the desktop.

The app has no window or Dock icon. It opens at login and stays in the background (turn that off under System Settings > General > Login Items); opening it from Finder or Spotlight shows the box.

## How it works

- `Sources/StickyCore`: the notes model (`StickyBoard`, immutable), the file store, the drag-to-reorder arithmetic, and the `stickynotes://add` link. `swift test` covers it.
- `App`: the background app that shows the box (add field plus the draggable list) and the inline edit field. It finds the widget on screen through the window list and places the field from `WidgetLayout`, the same numbers the widget draws with (the widget turns off the system content margins so nothing else moves it).
- Dragging on the widget: widgets only take clicks, so the app keeps an invisible panel over each note's text, one level above the widget window. A quick click there opens the edit field; a hold or a drag lifts the note, and the app draws the rows over the widget (from the same views, in `Shared`) while they slide, saves the new order, and fades once the widget has redrawn. The rows stay up until the widget says it has redrawn (it touches `widget-drawn` next to the notes file). macOS doesn't say which desktop window is which widget, so the app learns its widget's window whenever the widget opens one of its links (they carry `from=widget`), and remembers the last few, since each display arrangement gets its own window. Until the first click on the widget after an install, a drag there does nothing special. A right-click on a note's text lands on a catcher too; the catchers then step aside for 3 seconds, so a second right-click opens the widget's own menu.
- `Widget`: the WidgetKit extension. A note's circle and x are App Intents that edit the notes file from the widget's own process, so it works even when the app isn't running.

Widget buttons only work once macOS's App Intents index has the installed app. Xcode registers its own build copy, and dropping that copy can make the index forget the app, so `build.sh` retires the build copy, registers the installed one, and checks the index took it. If it prints a warning, run it again.

Notes live in `~/Library/Application Support/Sticky Notes/notes.json`. The widget is sandboxed with an exception for that one folder. Set `STICKY_NOTES_PATH` to point the app (not the widget) at a different file.
