import Foundation
import UserNotifications

enum NotificationPreferences {
  static let allowanceWarningEnabledKey = "notifications.allowanceWarningEnabled"
  static let allowancesOffReminderEnabledKey = "notifications.allowancesOffReminderEnabled"
  static let allowancesOffCycleArmedKey = "notifications.allowancesOffCycleArmed"

  static var allowanceWarningEnabled: Bool {
    get {
      if let value = UserDefaults.standard.object(forKey: allowanceWarningEnabledKey) as? Bool {
        return value
      }
      return true
    }
    set {
      UserDefaults.standard.set(newValue, forKey: allowanceWarningEnabledKey)
    }
  }

  static var allowancesOffReminderEnabled: Bool {
    get {
      if let value = UserDefaults.standard.object(forKey: allowancesOffReminderEnabledKey) as? Bool {
        return value
      }
      return false
    }
    set {
      UserDefaults.standard.set(newValue, forKey: allowancesOffReminderEnabledKey)
    }
  }

  static var allowancesOffCycleArmed: Bool {
    get {
      UserDefaults.standard.bool(forKey: allowancesOffCycleArmedKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: allowancesOffCycleArmedKey)
    }
  }
}

enum UsageBasedNotificationScheduler {
  private static let allowancesOffReminderInitialId = "usageBased.allowancesOffReminder.initial"
  private static let allowancesOffReminderFollowUpId = "usageBased.allowancesOffReminder.followUp"

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

  static func reconcileAllowancesOffReminderCycle(
    isAllowancesOff: Bool,
    remindersEnabled: Bool
  ) {
    guard remindersEnabled else {
      resetAllowancesOffReminderCycle(cancelPending: true)
      return
    }

    if isAllowancesOff {
      armAllowancesOffReminderCycleIfNeeded()
    } else {
      resetAllowancesOffReminderCycle(cancelPending: true)
    }
  }

  private static func armAllowancesOffReminderCycleIfNeeded() {
    guard !NotificationPreferences.allowancesOffCycleArmed else {
      return
    }

    requestAuthorization()

    let initialContent = UNMutableNotificationContent()
    initialContent.title = "Allowances are off"
    initialContent.body = "No usage allowance is currently enabled or scheduled."
    initialContent.sound = .default

    let followUpContent = UNMutableNotificationContent()
    followUpContent.title = "Allowances are still off"
    followUpContent.body = "Turn on or schedule a usage allowance to keep limits active."
    followUpContent.sound = .default

    let initialTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
    let followUpTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 90 * 60, repeats: false)

    let initialRequest = UNNotificationRequest(
      identifier: allowancesOffReminderInitialId,
      content: initialContent,
      trigger: initialTrigger
    )

    let followUpRequest = UNNotificationRequest(
      identifier: allowancesOffReminderFollowUpId,
      content: followUpContent,
      trigger: followUpTrigger
    )

    let center = UNUserNotificationCenter.current()
    center.add(initialRequest) { error in
      if let error {
        NSLog("Failed to schedule allowances-off reminder: %@", error.localizedDescription)
      }
    }
    center.add(followUpRequest) { error in
      if let error {
        NSLog("Failed to schedule allowances-off follow-up reminder: %@", error.localizedDescription)
      }
    }

    NotificationPreferences.allowancesOffCycleArmed = true
  }

  private static func resetAllowancesOffReminderCycle(cancelPending: Bool) {
    NotificationPreferences.allowancesOffCycleArmed = false

    guard cancelPending else { return }

    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [
        allowancesOffReminderInitialId,
        allowancesOffReminderFollowUpId,
      ]
    )
  }
}