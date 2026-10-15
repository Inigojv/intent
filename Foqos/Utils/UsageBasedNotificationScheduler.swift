import Foundation
import UserNotifications

enum UsageBasedNotificationScheduler {
  static func requestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .notDetermined else { return }
      center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
  }

  static func sendFiveMinutesLeft(for state: UsageBasedMonitoringState) {
    let content = UNMutableNotificationContent()
    content.title = "5 minutes left"
    content.body = "Your hourly allowance for selected apps is almost used."
    content.sound = .default

    let identifier =
      "usageBased.fiveMinutesLeft.\(state.profileId.uuidString).\(state.sessionId).\(Int(state.windowStart.timeIntervalSince1970))"
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil
    )

    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        NSLog("Failed to schedule usage allowance warning: %@", error.localizedDescription)
      }
    }
  }
}