//
//  DeviceActivityMonitorExtension.swift
//  FoqosDeviceMonitor
//
//  Created by Ali Waseem on 2025-05-27.
//

import DeviceActivity
import ManagedSettings
import OSLog

private let log = Logger(
  subsystem: "com.foqos.monitor",
  category: "DeviceActivity"
)

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let appBlocker = AppBlockerUtil()

  override init() {
    super.init()
  }

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)

    log.info("intervalDidStart for activity: \(activity.rawValue)")

    guard !activity.rawValue.hasPrefix("\(UsageBasedActivityScheduler.activityPrefix):") else {
      return
    }

    if UsageBasedActivityScheduler.currentState(for: activity) != nil {
      return
    }

    TimerActivityUtil.startTimerActivity(for: activity)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    log.info("intervalDidEnd for activity: \(activity.rawValue)")

    guard !activity.rawValue.hasPrefix("\(UsageBasedActivityScheduler.activityPrefix):") else {
      guard UsageBasedActivityScheduler.currentState(for: activity) != nil else {
        return
      }

      do {
        try UsageBasedActivityScheduler.advance(after: activity)
      } catch {
        log.error("Failed to schedule the next hourly usage interval: \(error.localizedDescription)")
      }
      UsageBasedActivityScheduler.rebuildRestrictions()
      return
    }

    TimerActivityUtil.stopTimerActivity(for: activity)
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)

    if let minute = UsageBasedActivityScheduler.minuteTickMinute(from: event) {
      UsageBasedActivityScheduler.recordUsageTick(minute: minute, for: activity)
      return
    }

    if event == UsageBasedActivityScheduler.warningEventName {
      guard let state = UsageBasedActivityScheduler.markWarningSent(for: activity) else {
        return
      }
      UsageBasedNotificationScheduler.sendFiveMinutesLeft(for: state)
      return
    }

    guard event == UsageBasedActivityScheduler.thresholdEvent,
      let _ = UsageBasedActivityScheduler.markAllowanceReached(for: activity)
    else { return }

    UsageBasedActivityScheduler.rebuildRestrictions()
  }
}
