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
    TimerActivityUtil.startTimerActivity(for: activity)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)

    log.info("intervalDidEnd for activity: \(activity.rawValue)")
    if UsageBasedActivityScheduler.currentState(for: activity) != nil {
      appBlocker.deactivateUsageBasedRestrictions()
      do {
        try UsageBasedActivityScheduler.advance(after: activity)
      } catch {
        log.error("Failed to schedule the next hourly usage interval: \(error.localizedDescription)")
      }
      return
    }

    TimerActivityUtil.stopTimerActivity(for: activity)
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name,
    activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)

    guard event == UsageBasedActivityScheduler.thresholdEvent,
      let state = UsageBasedActivityScheduler.currentState(for: activity),
      let currentWindow = UsageBasedActivityScheduler.hourlyWindow(containing: Date()),
      state.windowStart == currentWindow.start
    else {
      return
    }

    appBlocker.activateUsageBasedRestrictions(
      applicationTokens: state.applicationTokens,
      categoryTokens: state.categoryTokens,
      webDomainTokens: state.webDomainTokens
    )
  }
}
