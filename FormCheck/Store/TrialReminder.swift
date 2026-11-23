import Foundation
import UserNotifications

/// Keeps the paywall's promise: "we'll remind you 2 days before your trial
/// ends." A local notification — nothing leaves the device.
enum TrialReminder {
    private static let id = "formcheck.trial-reminder"

    static func requestPermissionIfTrial(endDate: Date?) async {
        guard endDate != nil else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        if let endDate { schedule(trialEnds: endDate) }
    }

    static func schedule(trialEnds end: Date) {
        let center = UNUserNotificationCenter.current()
        // Two days before, or one day before for very short trials.
        var fire = end.addingTimeInterval(-2 * 86_400)
        if fire < Date().addingTimeInterval(3_600) { fire = end.addingTimeInterval(-86_400) }
        guard fire > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in \(fire == end.addingTimeInterval(-86_400) ? "1 day" : "2 days")"
        content.body = "Bones here 💀 Keep unlimited form coaching, or cancel anytime in Settings → Subscriptions. No hard feelings."
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

/// One fully-featured scored set per day for free users — enough to feel the
/// magic (and come back tomorrow), not enough to replace Pro.
enum FreePass {
    private static let key = "freePass.lastUsedDay"

    static var availableToday: Bool {
        UserDefaults.standard.string(forKey: key) != today
    }

    static func consume() {
        UserDefaults.standard.set(today, forKey: key)
    }

    private static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
