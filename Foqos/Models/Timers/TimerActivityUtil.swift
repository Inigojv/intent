import DeviceActivity

class TimerActivityUtil {
  static func startTimerActivity(for activity: DeviceActivityName) {
    let parts = getTimerParts(from: activity)

    guard let timerActivity = getTimerActivity(for: parts.deviceActivityId),
      let profile = getProfile(for: timerActivity.profileId(from: activity))
    else {
      return
    }

    let previousSession = SharedData.getActiveSharedSession()
    timerActivity.start(for: profile, activityName: activity)
    publishSessionChange(from: previousSession, callbackProfile: profile)
  }

  static func stopTimerActivity(for activity: DeviceActivityName) {
    let parts = getTimerParts(from: activity)

    guard let timerActivity = getTimerActivity(for: parts.deviceActivityId),
      let profile = getProfile(for: timerActivity.profileId(from: activity))
    else {
      return
    }

    let previousSession = SharedData.getActiveSharedSession()
    timerActivity.stop(for: profile, activityName: activity)
    publishSessionChange(from: previousSession, callbackProfile: profile)
  }

  private static func publishSessionChange(
    from previousSession: SharedData.SessionSnapshot?,
    callbackProfile: SharedData.ProfileSnapshot
  ) {
    let currentSession = SharedData.getActiveSharedSession()
    guard currentSession != previousSession else { return }

    // Mac sync has been retired; no cloud profile state is published from the app anymore.
    ActiveProfileSyncStore.publish(session: nil, profile: nil)
  }

  private static func getTimerParts(from activity: DeviceActivityName) -> (
    deviceActivityId: String, profileId: String
  ) {
    let activityName = activity.rawValue
    let components = activityName.split(separator: ":", maxSplits: 1)

    // For versions >= 1.24, the activity name format is "type:profileId"
    if components.count == 2 {
      return (deviceActivityId: String(components[0]), profileId: String(components[1]))
    }

    // For versions < 1.24, the activity name format is just "profileId" and only supports schedule timer activity
    // This is to support backward compatibility for older schedules
    return (deviceActivityId: ScheduleTimerActivity.id, profileId: activityName)
  }

  private static func getTimerActivity(for deviceActivityId: String) -> TimerActivity? {
    switch deviceActivityId {
    case ScheduleTimerActivity.id:
      return ScheduleTimerActivity()
    case BreakTimerActivity.id:
      return BreakTimerActivity()
    case StrategyTimerActivity.id:
      return StrategyTimerActivity()
    case PauseTimerActivity.id:
      return PauseTimerActivity()
    case SoftUnblockGrantTimerActivity.id:
      return SoftUnblockGrantTimerActivity()
    default:
      return nil
    }
  }

  private static func getProfile(for profileId: String) -> SharedData.ProfileSnapshot? {
    return SharedData.snapshot(for: profileId)
  }

  private static func getProfile(
    for session: SharedData.SessionSnapshot?,
    callbackProfile: SharedData.ProfileSnapshot
  ) -> SharedData.ProfileSnapshot? {
    guard let session else { return nil }
    if session.blockedProfileId == callbackProfile.id {
      return callbackProfile
    }
    return getProfile(for: session.blockedProfileId.uuidString)
  }
}
