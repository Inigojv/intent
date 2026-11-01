import DeviceActivity
import Foundation
import ManagedSettings

struct UsageBasedMonitoringState: Codable, Equatable {
  let profileId: UUID
  let sessionId: String
  let applicationTokens: Set<ApplicationToken>
  let categoryTokens: Set<ActivityCategoryToken>
  let webDomainTokens: Set<WebDomainToken>
  var allowanceInMinutes: Int
  let enableFiveMinuteWarning: Bool
  var extraTimeInMinutes: Int
  var enableExtraTimeReduction: Bool
  var extraTimeCooldownInSeconds: Int
  var windowStart: Date
  var warningSent = false
  var allowanceReached = false
  var extraTimeUsedCount = 0
  var extraTimeCooldownUntil: Date?

  init(
    profileId: UUID,
    sessionId: String,
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>,
    allowanceInMinutes: Int,
    enableFiveMinuteWarning: Bool = true,
    extraTimeInMinutes: Int = UsageBasedStrategyData.defaultExtraTimeInMinutes,
    enableExtraTimeReduction: Bool = UsageBasedStrategyData.defaultExtraTimeReductionEnabled,
    extraTimeCooldownInSeconds: Int = UsageBasedStrategyData.defaultExtraTimeCooldownInSeconds,
    windowStart: Date,
    warningSent: Bool = false,
    allowanceReached: Bool = false,
    extraTimeUsedCount: Int = 0,
    extraTimeCooldownUntil: Date? = nil
  ) {
    self.profileId = profileId
    self.sessionId = sessionId
    self.applicationTokens = applicationTokens
    self.categoryTokens = categoryTokens
    self.webDomainTokens = webDomainTokens
    self.allowanceInMinutes = allowanceInMinutes
    self.enableFiveMinuteWarning = enableFiveMinuteWarning
    self.extraTimeInMinutes = extraTimeInMinutes
    self.enableExtraTimeReduction = enableExtraTimeReduction
    self.extraTimeCooldownInSeconds = extraTimeCooldownInSeconds
    self.windowStart = windowStart
    self.warningSent = warningSent
    self.allowanceReached = allowanceReached
    self.extraTimeUsedCount = extraTimeUsedCount
    self.extraTimeCooldownUntil = extraTimeCooldownUntil
  }

  private enum CodingKeys: String, CodingKey {
    case profileId
    case sessionId
    case applicationTokens
    case categoryTokens
    case webDomainTokens
    case allowanceInMinutes
    case enableFiveMinuteWarning
    case extraTimeInMinutes
    case enableExtraTimeReduction
    case extraTimeCooldownInSeconds
    case windowStart
    case warningSent
    case allowanceReached
    case extraTimeUsedCount
    case extraTimeCooldownUntil
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    profileId = try container.decode(UUID.self, forKey: .profileId)
    sessionId = try container.decode(String.self, forKey: .sessionId)
    applicationTokens = try container.decode(Set<ApplicationToken>.self, forKey: .applicationTokens)
    categoryTokens = try container.decode(Set<ActivityCategoryToken>.self, forKey: .categoryTokens)
    webDomainTokens = try container.decode(Set<WebDomainToken>.self, forKey: .webDomainTokens)
    allowanceInMinutes = try container.decode(Int.self, forKey: .allowanceInMinutes)
    enableFiveMinuteWarning = try container.decodeIfPresent(
      Bool.self,
      forKey: .enableFiveMinuteWarning
    ) ?? true
    extraTimeInMinutes = try container.decodeIfPresent(
      Int.self,
      forKey: .extraTimeInMinutes
    ) ?? UsageBasedStrategyData.defaultExtraTimeInMinutes
    enableExtraTimeReduction = try container.decodeIfPresent(
      Bool.self,
      forKey: .enableExtraTimeReduction
    ) ?? UsageBasedStrategyData.defaultExtraTimeReductionEnabled
    extraTimeCooldownInSeconds = try container.decodeIfPresent(
      Int.self,
      forKey: .extraTimeCooldownInSeconds
    ) ?? UsageBasedStrategyData.defaultExtraTimeCooldownInSeconds
    windowStart = try container.decode(Date.self, forKey: .windowStart)
    warningSent = try container.decodeIfPresent(Bool.self, forKey: .warningSent) ?? false
    allowanceReached = try container.decodeIfPresent(Bool.self, forKey: .allowanceReached) ?? false
    extraTimeUsedCount = try container.decodeIfPresent(Int.self, forKey: .extraTimeUsedCount) ?? 0
    extraTimeCooldownUntil = try container.decodeIfPresent(Date.self, forKey: .extraTimeCooldownUntil)
  }

  mutating func grantExtraTime(at date: Date = Date()) -> Int {
    if let cooldownUntil = extraTimeCooldownUntil, date < cooldownUntil {
      return 0
    }

    let grantAmount = enableExtraTimeReduction
      ? max(
        1,
        Int(
          ceil(Double(extraTimeInMinutes) / pow(2.0, Double(max(0, extraTimeUsedCount))))
        )
      )
      : extraTimeInMinutes

    allowanceInMinutes += grantAmount
    extraTimeUsedCount += 1
    extraTimeCooldownUntil = date.addingTimeInterval(Double(extraTimeCooldownInSeconds))
    warningSent = false
    allowanceReached = false
    return grantAmount
  }

  var activityName: DeviceActivityName {
    DeviceActivityName(
      rawValue:
        "\(UsageBasedActivityScheduler.activityPrefix):\(profileId.uuidString):\(sessionId):\(Int(windowStart.timeIntervalSince1970))"
    )
  }

  mutating func markWarningSent() -> Bool {
    guard !warningSent, !allowanceReached else { return false }
    warningSent = true
    return true
  }

  mutating func markAllowanceReached() -> Bool {
    guard !allowanceReached else { return false }
    allowanceReached = true
    return true
  }

  mutating func beginWindow(at date: Date) {
    windowStart = date
    warningSent = false
    allowanceReached = false
  }
}

enum UsageBasedActivityScheduler {
  static let activityPrefix = "UsageBasedBlockingActivity"
  static let thresholdEvent = DeviceActivityEvent.Name("usageAllowanceReached")
  static let warningEventName = DeviceActivityEvent.Name("usageFiveMinutesRemaining")

  private static let stateKey = "usageBasedBlocking.monitoringState"
  private static let statesKey = "usageBasedBlocking.monitoringStates"
  private static let suite = UserDefaults(suiteName: "group.dev.ambitionsoftware.foqos")!

  static var allStates: [UsageBasedMonitoringState] {
    if let data = suite.data(forKey: statesKey),
      let states = try? JSONDecoder().decode([UsageBasedMonitoringState].self, from: data)
    {
      return states
    }

    guard let data = suite.data(forKey: stateKey),
      let state = try? JSONDecoder().decode(UsageBasedMonitoringState.self, from: data)
    else {
      return []
    }

    return [state]
  }

  static var currentState: UsageBasedMonitoringState? {
    allStates.last
  }

  static func currentState(for activity: DeviceActivityName) -> UsageBasedMonitoringState? {
    allStates.first { $0.activityName == activity }
  }

  static func state(for sessionId: String) -> UsageBasedMonitoringState? {
    allStates.first { $0.sessionId == sessionId }
  }

  static func rebuildRestrictions() {
    let states = allStates
    guard !states.isEmpty else {
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      return
    }

    let applicationTokens = Set(states.flatMap { $0.applicationTokens })
    let categoryTokens = Set(states.flatMap { $0.categoryTokens })
    let webDomainTokens = Set(states.flatMap { $0.webDomainTokens })

    AppBlockerUtil().activateUsageBasedRestrictions(
      applicationTokens: applicationTokens,
      categoryTokens: categoryTokens,
      webDomainTokens: webDomainTokens
    )
  }

  static func sessionId(from activity: DeviceActivityName) -> String? {
    let components = activity.rawValue.split(separator: ":")
    guard components.count == 4,
      components[0] == Substring(activityPrefix),
      UUID(uuidString: String(components[1])) != nil
    else {
      return nil
    }
    return String(components[2])
  }

  static func start(
    profileId: UUID,
    sessionId: String,
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>,
    allowanceInMinutes: Int,
    enableFiveMinuteWarning: Bool = true,
    extraTimeInMinutes: Int = UsageBasedStrategyData.defaultExtraTimeInMinutes,
    enableExtraTimeReduction: Bool = UsageBasedStrategyData.defaultExtraTimeReductionEnabled,
    extraTimeCooldownInSeconds: Int = UsageBasedStrategyData.defaultExtraTimeCooldownInSeconds,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) throws {
    guard
      !applicationTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty
    else {
      throw UsageBasedActivityError.noSelectedActivities
    }

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
      enableFiveMinuteWarning: enableFiveMinuteWarning,
      extraTimeInMinutes: min(
        max(extraTimeInMinutes, UsageBasedStrategyData.extraTimeRangeInMinutes.lowerBound),
        UsageBasedStrategyData.extraTimeRangeInMinutes.upperBound
      ),
      enableExtraTimeReduction: enableExtraTimeReduction,
      extraTimeCooldownInSeconds: min(
        max(extraTimeCooldownInSeconds, UsageBasedStrategyData.extraTimeCooldownRangeInSeconds.lowerBound),
        UsageBasedStrategyData.extraTimeCooldownRangeInSeconds.upperBound
      ),
      windowStart: window.start
    )

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
    nextState.beginWindow(at: nextWindow.start)
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
    enableFiveMinuteWarning: Bool = true,
    extraTimeInMinutes: Int = UsageBasedStrategyData.defaultExtraTimeInMinutes,
    enableExtraTimeReduction: Bool = UsageBasedStrategyData.defaultExtraTimeReductionEnabled,
    extraTimeCooldownInSeconds: Int = UsageBasedStrategyData.defaultExtraTimeCooldownInSeconds,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) throws {
    guard let window = hourlyWindow(containing: date, calendar: calendar) else {
      throw UsageBasedActivityError.invalidHourlyWindow
    }

    guard var state = state(for: sessionId),
      state.profileId == profileId
    else {
      UsageBasedActivityScheduler.rebuildRestrictions()
      try start(
        profileId: profileId,
        sessionId: sessionId,
        applicationTokens: applicationTokens,
        categoryTokens: categoryTokens,
        webDomainTokens: webDomainTokens,
        allowanceInMinutes: allowanceInMinutes,
        enableFiveMinuteWarning: enableFiveMinuteWarning,
        extraTimeInMinutes: extraTimeInMinutes,
        enableExtraTimeReduction: enableExtraTimeReduction,
        extraTimeCooldownInSeconds: extraTimeCooldownInSeconds,
        at: date,
        calendar: calendar
      )
      return
    }

    let center = DeviceActivityCenter()
    if state.windowStart != window.start {
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      center.stopMonitoring([state.activityName])
      state.beginWindow(at: window.start)
      save(state)
      try schedule(state, window: window, calendar: calendar)
      return
    }

    if !center.activities.contains(state.activityName) {
      try schedule(state, window: window, calendar: calendar)
    }
  }

  static func grantExtraTime(
    for activity: DeviceActivityName,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) -> UsageBasedMonitoringState? {
    guard var state = currentState(for: activity),
      let window = hourlyWindow(containing: date, calendar: calendar),
      state.windowStart == window.start
    else {
      return nil
    }

    let grantAmount = state.grantExtraTime(at: date)
    guard grantAmount > 0 else {
      return nil
    }

    save(state)
    AppBlockerUtil().deactivateUsageBasedRestrictions()

    let center = DeviceActivityCenter()
    center.stopMonitoring([activity])
    do {
      try schedule(state, window: window, calendar: calendar)
    } catch {
      return nil
    }

    return state
  }

  static func stop(sessionId: String) {
    let center = DeviceActivityCenter()
    let activities = center.activities.filter { Self.sessionId(from: $0) == sessionId }
    if !activities.isEmpty {
      center.stopMonitoring(activities)
    }
    clear(sessionId: sessionId)
  }

  static func hourlyWindow(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
    calendar.dateInterval(of: .hour, for: date)
  }

  static func event(for state: UsageBasedMonitoringState) -> DeviceActivityEvent {
    event(for: state, thresholdInMinutes: state.allowanceInMinutes)
  }

  static func warningEvent(for state: UsageBasedMonitoringState) -> DeviceActivityEvent? {
    guard state.enableFiveMinuteWarning, state.allowanceInMinutes > 1 else { return nil }
    return event(for: state, thresholdInMinutes: state.allowanceInMinutes - 1)
  }

  static func markWarningSent(
    for activity: DeviceActivityName,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) -> UsageBasedMonitoringState? {
    guard var state = currentState(for: activity),
      let window = hourlyWindow(containing: date, calendar: calendar),
      state.windowStart == window.start,
      state.markWarningSent()
    else {
      return nil
    }

    save(state)
    return state
  }

  static func markAllowanceReached(
    for activity: DeviceActivityName,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) -> UsageBasedMonitoringState? {
    guard var state = currentState(for: activity),
      let window = hourlyWindow(containing: date, calendar: calendar),
      state.windowStart == window.start,
      state.markAllowanceReached()
    else {
      return nil
    }

    save(state)
    return state
  }

  private static func event(
    for state: UsageBasedMonitoringState,
    thresholdInMinutes: Int
  ) -> DeviceActivityEvent {
    DeviceActivityEvent(
      applications: state.applicationTokens,
      categories: state.categoryTokens,
      webDomains: state.webDomainTokens,
      threshold: DateComponents(minute: thresholdInMinutes),
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
    var events = [Self.thresholdEvent: Self.event(for: state)]
    if let warningEvent = Self.warningEvent(for: state) {
      events[Self.warningEventName] = warningEvent
    }

    try DeviceActivityCenter().startMonitoring(
      state.activityName,
      during: schedule,
      events: events
    )
  }

  private static func save(_ state: UsageBasedMonitoringState) {
    var states = allStates.filter { $0.sessionId != state.sessionId }
    states.append(state)

    guard let data = try? JSONEncoder().encode(states) else { return }
    suite.set(data, forKey: statesKey)
    suite.removeObject(forKey: stateKey)
  }

  private static func clear(sessionId: String) {
    let states = allStates.filter { $0.sessionId != sessionId }

    if states.isEmpty {
      suite.removeObject(forKey: statesKey)
      suite.removeObject(forKey: stateKey)
      return
    }

    guard let data = try? JSONEncoder().encode(states) else { return }
    suite.set(data, forKey: statesKey)
  }
}

enum UsageBasedActivityError: Error {
  case invalidHourlyWindow
  case noSelectedActivities
}