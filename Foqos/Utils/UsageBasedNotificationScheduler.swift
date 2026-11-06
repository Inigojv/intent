import Foundation
import UserNotifications

enum UsageBasedNotificationScheduler {
  static func requestAuthorization() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .notDetermined else { return }
      center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
  }

  static func sendAllowanceWarning(for state: UsageBasedMonitoringState) {
    let content = UNMutableNotificationContent()
    content.title = "Time to wrap up"
    content.body = "Your allowance is running out."
    content.sound = .default

    let identifier =
      "usageBased.allowanceWarning.\(state.profileId.uuidString).\(state.sessionId).\(Int(state.windowStart.timeIntervalSince1970))"
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