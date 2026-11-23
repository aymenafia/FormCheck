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

/// Opt-in daily nudge from Bones at the user's training time. One repeating
/// notification per weekday so the copy doesn't go stale. Local only.
enum WorkoutReminder {
    static let enabledKey = "reminder.enabled"
    static let minutesKey = "reminder.minutes"   // minutes after midnight
    static let askedKey = "reminder.asked"
    private static let prefix = "formcheck.workout."

    static var minutes: Int {
        let m = UserDefaults.standard.object(forKey: minutesKey) as? Int
        return m ?? 18 * 60
    }

    private static let lines: [String] = [
        "Sunday squats hit different. One set, I'll grade it. 💀",
        "Monday = new grade. Prop the phone, let's go.",
        "Your knees called. They want a form check.",
        "Midweek check-in: one clean set keeps the streak alive. 🔥",
        "Bet you can beat your last grade today.",
        "Friday form check — finish the week strong.",
        "Weekend lifters get the best grades. Prove it.",
    ]

    /// Asks permission if needed; returns whether reminders are now on.
    @discardableResult
    static func enable(at minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            status = await center.notificationSettings().authorizationStatus
        }
        UserDefaults.standard.set(true, forKey: askedKey)
        guard status == .authorized || status == .provisional else {
            UserDefaults.standard.set(false, forKey: enabledKey)
            return false
        }
        UserDefaults.standard.set(minutes, forKey: minutesKey)
        UserDefaults.standard.set(true, forKey: enabledKey)
        schedule(minutes: minutes)
        return true
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (1...7).map { prefix + "\($0)" })
    }

    private static func schedule(minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { prefix + "\($0)" })
        for weekday in 1...7 {
            let content = UNMutableNotificationContent()
            content.title = "Bones is waiting"
            content.body = lines[weekday - 1]
            content.sound = .default
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = minutes / 60
            comps.minute = minutes % 60
            center.add(UNNotificationRequest(identifier: prefix + "\(weekday)", content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
        }
    }
}
