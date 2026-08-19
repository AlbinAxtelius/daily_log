//
//  NudgeCenter.swift
//  daily_log
//
//  Silence-based nudges during the day, one summary at end of day.
//
//  Both are driven by in-process timers rather than calendar triggers: the app is
//  always running, the notification body needs *current* data, and pending banners
//  must vanish on sleep/lock instead of piling up behind the lock screen.
//

import AppKit
import UserNotifications

enum NudgeID {
    static let nudgeCategory = "daily.nudge"
    /// Stable, so a repeat nudge replaces the ignored one instead of stacking.
    static let nudgeRequest = "daily.nudge.request"
    static let eodCategory = "daily.eod"
    static let sameAsBefore = "daily.action.same"
    static let open = "daily.action.open"
}

@MainActor
final class NudgeCenter: NSObject {
    /// The live instance, so the settings screen can fire test notifications.
    static private(set) weak var current: NudgeCenter?

    private let store: Store
    private weak var coordinator: AppCoordinator?

    private var silenceTimer: Timer?
    private var endOfDayTimer: Timer?
    private var suspended = false

    /// When the last nudge went out. Newer than the last entry means it went unanswered.
    private var lastNudgeAt: Date?

    private let center = UNUserNotificationCenter.current()

    init(store: Store, coordinator: AppCoordinator) {
        self.store = store
        self.coordinator = coordinator
        super.init()

        // Categories must exist before anything is ever scheduled.
        center.delegate = self
        registerCategories()

        observeSystemEvents()
        NudgeCenter.current = self
    }

    // MARK: - Setup

    private func registerCategories() {
        let same = UNNotificationAction(
            identifier: NudgeID.sameAsBefore, title: "Same as before", options: []
        )
        let open = UNNotificationAction(
            identifier: NudgeID.open, title: "Open", options: [.foreground]
        )
        // macOS folds a third action into an "Options" menu, so there are only ever two.
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NudgeID.nudgeCategory, actions: [same, open],
                                   intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NudgeID.eodCategory, actions: [open],
                                   intentIdentifiers: [], options: []),
        ])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake),
                              name: NSWorkspace.didWakeNotification, object: nil)

        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(systemWillSleep),
                                name: .init("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(systemDidWake),
                                name: .init("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func systemWillSleep() {
        suspended = true
        silenceTimer?.invalidate(); silenceTimer = nil
        endOfDayTimer?.invalidate(); endOfDayTimer = nil
        center.removeAllPendingNotificationRequests()
        center.removeDeliveredNotifications(withIdentifiers: [NudgeID.nudgeRequest])
    }

    @objc private func systemDidWake() {
        suspended = false
        scheduleAll()
    }

    // MARK: - Scheduling

    func scheduleAll() {
        scheduleSilenceNudge()
        scheduleEndOfDay()
    }

    /// Logging anything resets this, so a well-logged day stays silent. An ignored nudge
    /// comes back after `repeatMinutes` instead of after the full silence window.
    func scheduleSilenceNudge() {
        silenceTimer?.invalidate()
        guard !suspended else { return }

        let settings = store.settings
        let now = Date()
        let logged = store.lastEntry.map { max($0.at, now.addingTimeInterval(-3600 * 24)) } ?? now

        var fire: Date
        if let nudged = lastNudgeAt, nudged > logged {
            // Still unanswered.
            guard settings.repeatMinutes > 0 else { return }
            fire = nudged.addingTimeInterval(Double(settings.repeatMinutes) * 60)
        } else {
            lastNudgeAt = nil
            fire = logged.addingTimeInterval(Double(settings.silenceMinutes) * 60)
        }
        // Never nag the instant the app launches or wakes.
        fire = max(fire, now.addingTimeInterval(60))
        fire = nextWorkTime(atOrAfter: fire)

        silenceTimer = schedule(at: fire) { [weak self] in self?.fireSilenceNudge() }
    }

    private func scheduleEndOfDay() {
        endOfDayTimer?.invalidate()
        guard !suspended else { return }
        guard let fire = nextEndOfDay(after: Date()) else { return }
        endOfDayTimer = schedule(at: fire) { [weak self] in self?.fireEndOfDay() }
    }

    private func schedule(at date: Date, _ action: @escaping () -> Void) -> Timer {
        let timer = Timer(fire: date, interval: 0, repeats: false) { _ in
            MainActor.assumeIsolated(action)
        }
        timer.tolerance = 15
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    // MARK: - Firing

    private func fireSilenceNudge() {
        defer { scheduleSilenceNudge() }
        guard store.settings.isWorkTime(Date()) else { return }
        lastNudgeAt = Date()
        deliver(silenceContent(), id: NudgeID.nudgeRequest)
    }

    private func fireEndOfDay() {
        defer { scheduleEndOfDay() }
        deliver(endOfDayContent())
    }

    private func silenceContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if let last = store.lastEntry {
            content.title = "Still on \(store.displayName(last.project))?"
            content.body = last.note.isEmpty ? "" : "Last: \(last.note)"
        } else {
            content.title = "What are you working on?"
            content.body = "Nothing logged yet today."
        }
        content.categoryIdentifier = NudgeID.nudgeCategory
        content.interruptionLevel = .timeSensitive
        
        return content
    }

    private func endOfDayContent() -> UNMutableNotificationContent {
        let day = store.today
        let content = UNMutableNotificationContent()
        content.title = "Daily — \(Fmt.dayLong.string(from: day))"
        content.subtitle = store.rollupLine(onDay: day)
        content.body = {
            let notes = store.noteLine(onDay: day)
            return notes.isEmpty ? "" : "\"\(notes)\""
        }()
        content.categoryIdentifier = NudgeID.eodCategory
        return content
    }

    private func deliver(_ content: UNMutableNotificationContent, id: String = UUID().uuidString) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - Testing

    enum TestKind {
        case silence
        case endOfDay

        var label: String {
            switch self {
            case .silence: "nudge"
            case .endOfDay: "summary"
            }
        }
    }

    enum TestOutcome {
        case delivered(String)
        case blocked(String)
    }

    /// Everything that decides whether a banner will actually appear on screen.
    struct Diagnostics {
        var authorization: UNAuthorizationStatus
        var alertStyle: UNAlertStyle
        var isBundled: Bool

        var summary: String {
            switch authorization {
            case .notDetermined: return "Not asked yet"
            case .denied: return "Denied in System Settings"
            case .authorized, .provisional, .ephemeral:
                return alertStyle == .none ? "Allowed, but banners are off" : "Allowed"
            @unknown default: return "Unknown"
            }
        }

        var isHealthy: Bool {
            guard isBundled, alertStyle != .none else { return false }
            return authorization == .authorized || authorization == .provisional
        }
    }

    func diagnostics() async -> Diagnostics {
        let settings = await center.notificationSettings()
        return Diagnostics(
            authorization: settings.authorizationStatus,
            alertStyle: settings.alertStyle,
            // `UNUserNotificationCenter` silently does nothing outside a real .app bundle.
            isBundled: Bundle.main.bundleIdentifier != nil
        )
    }

    /// Posts the real thing — same content, same category, live actions — right now.
    /// A `delay` lets you get the app out of the way first.
    func sendTest(_ kind: TestKind, after delay: TimeInterval = 0) async -> TestOutcome {
        let diagnostics = await diagnostics()
        guard diagnostics.isBundled else {
            return .blocked("Not running from a built .app — notifications are unavailable.")
        }
        switch diagnostics.authorization {
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else { return .blocked("Permission declined.") }
        case .denied:
            return .blocked("Notifications are off for Daily in System Settings.")
        default:
            break
        }

        let content = kind == .silence ? silenceContent() : endOfDayContent()
        content.sound = .default
        let trigger = delay > 0
            ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            : nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            return .blocked(error.localizedDescription)
        }

        if diagnostics.alertStyle == .none {
            return .blocked("Delivered, but Daily's alert style is None — check Notification Centre.")
        }
        return delay > 0
            ? .delivered("Test \(kind.label) in \(Int(delay))s.")
            : .delivered("Test \(kind.label) sent.")
    }

    // MARK: - Work-window arithmetic

    /// `date` if it already falls in the work window, otherwise the next window opening.
    private func nextWorkTime(atOrAfter date: Date) -> Date {
        let settings = store.settings
        if settings.isWorkTime(date) { return date }

        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)
        for _ in 0...14 {
            let opening = day.addingTimeInterval(Double(settings.workStartMinutes) * 60)
            if opening >= date, settings.isWorkTime(opening) { return opening }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return date.addingTimeInterval(3600)
    }

    private func nextEndOfDay(after date: Date) -> Date? {
        let settings = store.settings
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)
        for _ in 0...14 {
            let fire = day.addingTimeInterval(Double(settings.endOfDayMinutes) * 60)
            if fire > date, settings.workDays.contains(calendar.component(.weekday, from: fire)) {
                return fire
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return nil
    }
}

// MARK: - Responses

extension NudgeCenter: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier
        await MainActor.run { handle(action: action, category: category) }
    }

    private func handle(action: String, category: String) {
        switch action {
        case NudgeID.sameAsBefore:
            // A true continuation: same project *and* same note, so no description hole.
            if let last = store.lastEntry {
                store.log(project: last.project, note: last.note)
            } else {
                coordinator?.showCapture()
            }
        case NudgeID.open:
            coordinator?.showMainWindow(day: store.today)
        case UNNotificationDefaultActionIdentifier:
            if category == NudgeID.eodCategory {
                coordinator?.showMainWindow(day: store.today)
            } else {
                coordinator?.showCapture()
            }
        default:
            break
        }
    }
}
