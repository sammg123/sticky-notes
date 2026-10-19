# Sticky Notes

A desktop widget for quick notes on macOS. Nothing else. The widget is called Notes.

- **Add:** click the widget (the + in its corner) and a small box opens. Type the note and press Return. Escape or a click elsewhere closes the box without saving.
- **Cross out:** click the circle next to a note; it turns into a checkmark. Click it again to bring the note back.
- **Remove:** a crossed-out note gets an x at the end of its line; click it to delete the note.
- **Reorder:** the box the widget opens lists every note under the text field. Drag a note up or down; the others slide out of the way and it snaps into place when you let go. The circle and x work there too. (macOS widgets can't be dragged inside, so reordering lives in the box.)

Newest notes sit at the top. Small and medium widgets show 4 rows and large shows 11. When the notes don't all fit, the last row tells you how many are hidden.

## Install

Needs macOS 14+, Xcode, and XcodeGen (`brew install xcodegen`).

```sh
./build.sh          # builds and installs ~/Applications/Sticky Notes.app
./build.sh --test   # runs the unit tests first
```

Then right-click the desktop, choose **Edit Widgets**, search for **Sticky Notes**, and drag the Notes widget onto the desktop.

The app has no window or Dock icon. It only runs to show the add box, and opening it from Finder or Spotlight shows the box too.

## How it works

- `Sources/StickyCore`: the notes model (`StickyBoard`, immutable), the file store, the drag-to-reorder arithmetic, and the `stickynotes://add` link. `swift test` covers it.
- `App`: the background app that shows the box (add field plus the draggable list).
- `Widget`: the WidgetKit extension. A note's circle and x are App Intents that edit the notes file from the widget's own process, so it works even when the app isn't running.

Widget buttons only work once macOS's App Intents index has the installed app. Xcode registers its own build copy, and dropping that copy can make the index forget the app, so `build.sh` retires the build copy, registers the installed one, and checks the index took it. If it prints a warning, run it again.

Notes live in `~/Library/Application Support/Sticky Notes/notes.json`. The widget is sandboxed with an exception for that one folder. Set `STICKY_NOTES_PATH` to point the app (not the widget) at a different file.
