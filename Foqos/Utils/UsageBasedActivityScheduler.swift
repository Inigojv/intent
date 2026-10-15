import DeviceActivity
import Foundation
import ManagedSettings

struct UsageBasedMonitoringState: Codable, Equatable {
  let profileId: UUID
  let sessionId: String
  let applicationTokens: Set<ApplicationToken>
  let categoryTokens: Set<ActivityCategoryToken>
  let webDomainTokens: Set<WebDomainToken>
  let allowanceInMinutes: Int
  var windowStart: Date

  var activityName: DeviceActivityName {
    DeviceActivityName(
      rawValue:
        "\(UsageBasedActivityScheduler.activityPrefix):\(profileId.uuidString):\(sessionId):\(Int(windowStart.timeIntervalSince1970))"
    )
  }
}

enum UsageBasedActivityScheduler {
  static let activityPrefix = "UsageBasedBlockingActivity"
  static let thresholdEvent = DeviceActivityEvent.Name("usageAllowanceReached")

  private static let stateKey = "usageBasedBlocking.monitoringState"
  private static let suite = UserDefaults(suiteName: "group.dev.ambitionsoftware.foqos")!

  static var currentState: UsageBasedMonitoringState? {
    guard let data = suite.data(forKey: stateKey) else { return nil }
    return try? JSONDecoder().decode(UsageBasedMonitoringState.self, from: data)
  }

  static func currentState(for activity: DeviceActivityName) -> UsageBasedMonitoringState? {
    guard let state = currentState, state.activityName == activity else { return nil }
    return state
  }

  static func start(
    profileId: UUID,
    sessionId: String,
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>,
    allowanceInMinutes: Int,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) throws {
    guard let window = hourlyWindow(containing: date, calendar: calendar) else {
      throw UsageBasedActivityError.invalidHourlyWindow
    }

    let state = UsageBasedMonitoringState(
      profileId: profileId,
      sessionId: sessionId,
      applicationTokens: applicationTokens,
      categoryTokens: categoryTokens,
      webDomainTokens: webDomainTokens,
      allowanceInMinutes: min(
        max(allowanceInMinutes, UsageBasedStrategyData.allowanceRangeInMinutes.lowerBound),
        UsageBasedStrategyData.allowanceRangeInMinutes.upperBound
      ),
      windowStart: window.start
    )

    if let previousState = currentState {
      DeviceActivityCenter().stopMonitoring([previousState.activityName])
    }

    save(state)
    do {
      try schedule(state, window: window, calendar: calendar)
    } catch {
      clear(sessionId: sessionId)
      throw error
    }
  }

  static func advance(
    after activity: DeviceActivityName,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) throws {
    guard let state = currentState(for: activity),
      let currentWindow = hourlyWindow(containing: date, calendar: calendar),
      let firstNextHour = calendar.date(byAdding: .hour, value: 1, to: state.windowStart)
    else {
      return
    }

    let nextWindowStart = max(firstNextHour, currentWindow.start)
    guard let nextWindow = hourlyWindow(containing: nextWindowStart, calendar: calendar) else {
      throw UsageBasedActivityError.invalidHourlyWindow
    }

    var nextState = state
    nextState.windowStart = nextWindow.start
    save(nextState)
    DeviceActivityCenter().stopMonitoring([activity])
    try schedule(nextState, window: nextWindow, calendar: calendar)
  }

  static func reconcile(
    profileId: UUID,
    sessionId: String,
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>,
    allowanceInMinutes: Int,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) throws {
    guard let window = hourlyWindow(containing: date, calendar: calendar) else {
      throw UsageBasedActivityError.invalidHourlyWindow
    }

    guard var state = currentState,
      state.profileId == profileId,
      state.sessionId == sessionId
    else {
      if let previousState = currentState {
        DeviceActivityCenter().stopMonitoring([previousState.activityName])
        clear(sessionId: previousState.sessionId)
      }
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      try start(
        profileId: profileId,
        sessionId: sessionId,
        applicationTokens: applicationTokens,
        categoryTokens: categoryTokens,
        webDomainTokens: webDomainTokens,
        allowanceInMinutes: allowanceInMinutes,
        at: date,
        calendar: calendar
      )
      return
    }

    let center = DeviceActivityCenter()
    if state.windowStart != window.start {
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      center.stopMonitoring([state.activityName])
      state.windowStart = window.start
      save(state)
      try schedule(state, window: window, calendar: calendar)
      return
    }

    if !center.activities.contains(state.activityName) {
      try schedule(state, window: window, calendar: calendar)
    }
  }

  static func stop(sessionId: String) {
    guard let state = currentState, state.sessionId == sessionId else { return }
    DeviceActivityCenter().stopMonitoring([state.activityName])
    clear(sessionId: sessionId)
  }

  static func hourlyWindow(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
    calendar.dateInterval(of: .hour, for: date)
  }

  static func event(for state: UsageBasedMonitoringState) -> DeviceActivityEvent {
    DeviceActivityEvent(
      applications: state.applicationTokens,
      categories: state.categoryTokens,
      webDomains: state.webDomainTokens,
      threshold: DateComponents(minute: state.allowanceInMinutes),
      includesPastActivity: true
    )
  }

  private static func schedule(
    _ state: UsageBasedMonitoringState,
    window: DateInterval,
    calendar: Calendar
  ) throws {
    let components: Set<Calendar.Component> = [
      .era, .year, .month, .day, .hour, .minute, .second,
    ]
    let intervalStart = calendar.dateComponents(components, from: window.start)
    let intervalEnd = calendar.dateComponents(components, from: window.end)
    let schedule = DeviceActivitySchedule(
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      repeats: false
    )
    let event = Self.event(for: state)

    try DeviceActivityCenter().startMonitoring(
      state.activityName,
      during: schedule,
      events: [Self.thresholdEvent: event]
    )
  }

  private static func save(_ state: UsageBasedMonitoringState) {
    guard let data = try? JSONEncoder().encode(state) else { return }
    suite.set(data, forKey: stateKey)
  }

  private static func clear(sessionId: String) {
    guard currentState?.sessionId == sessionId else { return }
    suite.removeObject(forKey: stateKey)
  }
}

enum UsageBasedActivityError: Error {
  case invalidHourlyWindow
}