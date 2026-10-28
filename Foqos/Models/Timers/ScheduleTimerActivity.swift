import DeviceActivity
import Foundation
import OSLog

private let log: Logger = Logger(subsystem: "com.foqos.monitor", category: ScheduleTimerActivity.id)

class ScheduleTimerActivity: TimerActivity {
  static var id: String = "ScheduleTimerActivity"

  // Device Activity callbacks can overlap on different handler instances.
  private static let transitionLock = NSLock()

  private let appBlocker = AppBlockerUtil()

  func getDeviceActivityName(from profileId: String) -> DeviceActivityName {
    // Since schedules were implemented before the timer activities, the profile id is used as the device activity name for
    // backward compatibility
    return DeviceActivityName(rawValue: profileId)
  }

  func getAllScheduleTimerActivities(from activities: [DeviceActivityName]) -> [DeviceActivityName]
  {
    // Schedule timer activities use just the profile UUID as the rawValue (no prefix)
    // Other activities use prefixes like "BreakScheduleActivity:" or "StrategyTimerActivity:"
    return activities.filter { activity in
      let rawValue = activity.rawValue
      // If it contains ":", it's a prefixed activity (break or strategy timer), not a schedule
      guard !rawValue.contains(":") else { return false }
      // Must be a valid UUID
      return UUID(uuidString: rawValue) != nil
    }
  }

  func start(for profile: SharedData.ProfileSnapshot) {
    Self.transitionLock.lock()
    defer { Self.transitionLock.unlock() }

    let profileId = profile.id.uuidString

    guard let schedule = profile.schedule
    else {
      log.info("Start schedule timer activity for \(profileId), no schedule for profile found")
      return
    }

    if !schedule.isTodayScheduled() {
      log.info(
        "Start schedule timer activity for \(profileId), schedule is not scheduled for today")
      return
    }

    if !schedule.olderThan15Minutes() {
      log.info("Start schedule timer activity for \(profileId), schedule is too new")
      return
    }

    log.info("Start schedule timer activity for \(profileId), profile: \(profileId)")

    if let existingSession = SharedData.getActiveSharedSession() {
      if existingSession.blockedProfileId == profile.id {
        log.info(
          "Start schedule timer activity for \(profileId), existing session profile matches device activity profile, continuing active session"
        )
        if profile.blockingStrategyId == UsageBasedBlockingStrategy.id {
          reconcileUsageBasedMonitoring(for: profile, sessionId: existingSession.id)
        }
        return
      } else {
        log.info(
          "Start schedule timer activity for \(profileId), existing session profile does not match device activity profile, ending active session"
        )
        SharedData.endActiveSharedSession()
      }
    }

    // Create a new active scheduled session for the profile
    let session = SharedData.createSessionForSchedular(for: profile.id)
    BlockingSessionLifecycleRegistry.sessionDidStart(
      BlockingSessionLifecycleContext(
        profile: profile,
        session: session
      )
    )

    startRestrictions(for: profile, session: session)
  }

  func stop(for profile: SharedData.ProfileSnapshot) {
    Self.transitionLock.lock()
    defer { Self.transitionLock.unlock() }

    let profileId = profile.id.uuidString

    guard let activeSession = SharedData.getActiveSharedSession() else {
      log.info("Stop schedule timer activity for \(profileId), no active session found")
      return
    }

    // Check to make sure the active session is the same as the profile before disabling restrictions
    if activeSession.blockedProfileId != profile.id {
      log.info(
        "Stop schedule timer activity for \(profileId), active session profile does not match device activity profile"
      )
      return
    }

    BlockingSessionLifecycleRegistry.sessionDidEnd(
      BlockingSessionLifecycleContext(
        profile: profile,
        session: activeSession
      )
    )

    if profile.blockingStrategyId != UsageBasedBlockingStrategy.id {
      appBlocker.deactivateRestrictions()
    }

    // End the active scheduled session
    SharedData.endActiveSharedSession()
  }

  func getScheduleInterval(from schedule: BlockedProfileSchedule) -> (
    intervalStart: DateComponents, intervalEnd: DateComponents
  ) {
    let intervalStart = DateComponents(hour: schedule.startHour, minute: schedule.startMinute)
    let intervalEnd = DateComponents(hour: schedule.endHour, minute: schedule.endMinute)
    return (intervalStart: intervalStart, intervalEnd: intervalEnd)
  }

  private func startRestrictions(
    for profile: SharedData.ProfileSnapshot,
    session: SharedData.SessionSnapshot
  ) {
    guard profile.blockingStrategyId == UsageBasedBlockingStrategy.id else {
      appBlocker.activateRestrictions(for: profile)
      return
    }

    appBlocker.deactivateRestrictions()
    do {
      try startUsageBasedMonitoring(for: profile, sessionId: session.id)
    } catch {
      log.error("Failed to start scheduled usage monitoring: \(error.localizedDescription)")
      BlockingSessionLifecycleRegistry.sessionDidEnd(
        BlockingSessionLifecycleContext(profile: profile, session: session)
      )
      SharedData.endActiveSharedSession()
    }
  }

  private func reconcileUsageBasedMonitoring(
    for profile: SharedData.ProfileSnapshot,
    sessionId: String
  ) {
    let configuration = UsageBasedStrategyData.decode(profile.strategyData)
    do {
      try UsageBasedActivityScheduler.reconcile(
        profileId: profile.id,
        sessionId: sessionId,
        applicationTokens: profile.selectedActivity.applicationTokens,
        categoryTokens: profile.selectedActivity.categoryTokens,
        webDomainTokens: profile.selectedActivity.webDomainTokens,
        allowanceInMinutes: configuration.allowanceInMinutes,
        enableFiveMinuteWarning: configuration.enableFiveMinuteWarning
      )
    } catch {
      log.error("Failed to resume scheduled usage monitoring: \(error.localizedDescription)")
    }
  }

  private func startUsageBasedMonitoring(
    for profile: SharedData.ProfileSnapshot,
    sessionId: String
  ) throws {
    let configuration = UsageBasedStrategyData.decode(profile.strategyData)
    try UsageBasedActivityScheduler.start(
      profileId: profile.id,
      sessionId: sessionId,
      applicationTokens: profile.selectedActivity.applicationTokens,
      categoryTokens: profile.selectedActivity.categoryTokens,
      webDomainTokens: profile.selectedActivity.webDomainTokens,
      allowanceInMinutes: configuration.allowanceInMinutes,
      enableFiveMinuteWarning: configuration.enableFiveMinuteWarning
    )
  }
}
