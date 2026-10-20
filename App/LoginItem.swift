import Foundation
import ServiceManagement
import os

/// Opens Sticky Notes at login, so dragging on the widget works from the start (only the app
/// can catch those presses). Asked once: if it's turned off in System Settings, that sticks.
enum LoginItem {
    private static let askedKey = "registeredLoginItem"
    private static let log = Logger(subsystem: "com.stickynotes.app", category: "LoginItem")

    static func registerOnce(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: askedKey) else { return }
        do {
            try SMAppService.mainApp.register()
            defaults.set(true, forKey: askedKey)
        } catch {
            log.error("Could not open at login: \(error.localizedDescription, privacy: .public)")
        }
    }
}
