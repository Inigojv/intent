import DeviceActivity
import Foundation
import ManagedSettings
import OSLog

struct UsageBasedMonitoringState: Codable, Equatable {
  let profileId: UUID
  let sessionId: String
  let applicationTokens: Set<ApplicationToken>
  let categoryTokens: Set<ActivityCategoryToken>
  let webDomainTokens: Set<WebDomainToken>
  let baseAllowanceInMinutes: Int
  var allowanceInMinutes: Int
  let enableFiveMinuteWarning: Bool
  var extraTimeInMinutes: Int
  var enableExtraTimeReduction: Bool
  var extraTimeCooldownInSeconds: Int
  var windowStart: Date
  var usedMinutes: Int
  var warningSent = false
  var allowanceReached = false
  var extraTimeUsedCount = 0
  var extraTimeCooldownUntil: Date?
  var monitorRevision: Int

  init(
    profileId: UUID,
    sessionId: String,
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>,
    baseAllowanceInMinutes: Int? = nil,
    allowanceInMinutes: Int,
    enableFiveMinuteWarning: Bool = true,
    extraTimeInMinutes: Int = UsageBasedStrategyData.defaultExtraTimeInMinutes,
    enableExtraTimeReduction: Bool = UsageBasedStrategyData.defaultExtraTimeReductionEnabled,
    extraTimeCooldownInSeconds: Int = UsageBasedStrategyData.defaultExtraTimeCooldownInSeconds,
    windowStart: Date,
    usedMinutes: Int = 0,
    warningSent: Bool = false,
    allowanceReached: Bool = false,
    extraTimeUsedCount: Int = 0,
    extraTimeCooldownUntil: Date? = nil,
    monitorRevision: Int = 0
  ) {
    self.profileId = profileId
    self.sessionId = sessionId
    self.applicationTokens = applicationTokens
    self.categoryTokens = categoryTokens
    self.webDomainTokens = webDomainTokens
    self.baseAllowanceInMinutes = baseAllowanceInMinutes ?? allowanceInMinutes
    self.allowanceInMinutes = allowanceInMinutes
    self.enableFiveMinuteWarning = enableFiveMinuteWarning
    self.extraTimeInMinutes = extraTimeInMinutes
    self.enableExtraTimeReduction = enableExtraTimeReduction
    self.extraTimeCooldownInSeconds = extraTimeCooldownInSeconds
    self.windowStart = windowStart
    self.usedMinutes = usedMinutes
    self.warningSent = warningSent
    self.allowanceReached = allowanceReached
    self.extraTimeUsedCount = extraTimeUsedCount
    self.extraTimeCooldownUntil = extraTimeCooldownUntil
    self.monitorRevision = monitorRevision
  }

  private enum CodingKeys: String, CodingKey {
    case profileId
    case sessionId
    case applicationTokens
    case categoryTokens
    case webDomainTokens
    case baseAllowanceInMinutes
    case allowanceInMinutes
    case enableFiveMinuteWarning
    case extraTimeInMinutes
    case enableExtraTimeReduction
    case extraTimeCooldownInSeconds
    case windowStart
    case usedMinutes
    case warningSent
    case allowanceReached
    case extraTimeUsedCount
    case extraTimeCooldownUntil
    case monitorRevision
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    profileId = try container.decode(UUID.self, forKey: .profileId)
    sessionId = try container.decode(String.self, forKey: .sessionId)
    applicationTokens = try container.decode(Set<ApplicationToken>.self, forKey: .applicationTokens)
    categoryTokens = try container.decode(Set<ActivityCategoryToken>.self, forKey: .categoryTokens)
    webDomainTokens = try container.decode(Set<WebDomainToken>.self, forKey: .webDomainTokens)
    allowanceInMinutes = try container.decode(Int.self, forKey: .allowanceInMinutes)
    baseAllowanceInMinutes = try container.decodeIfPresent(
      Int.self,
      forKey: .baseAllowanceInMinutes
    ) ?? allowanceInMinutes
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
    usedMinutes = try container.decodeIfPresent(Int.self, forKey: .usedMinutes) ?? 0
    warningSent = try container.decodeIfPresent(Bool.self, forKey: .warningSent) ?? false
    allowanceReached = try container.decodeIfPresent(Bool.self, forKey: .allowanceReached) ?? false
    extraTimeUsedCount = try container.decodeIfPresent(Int.self, forKey: .extraTimeUsedCount) ?? 0
    extraTimeCooldownUntil = try container.decodeIfPresent(Date.self, forKey: .extraTimeCooldownUntil)
    monitorRevision = try container.decodeIfPresent(Int.self, forKey: .monitorRevision) ?? 0
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
    monitorRevision += 1
    return grantAmount
  }

  var activityName: DeviceActivityName {
    DeviceActivityName(
      rawValue:
        "\(UsageBasedActivityScheduler.activityPrefix):\(profileId.uuidString):\(sessionId):\(Int(windowStart.timeIntervalSince1970)):\(monitorRevision)"
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
    allowanceInMinutes = baseAllowanceInMinutes
    usedMinutes = 0
    warningSent = false
    allowanceReached = false
    monitorRevision = 0
  }

  mutating func recordUsageTick(minute: Int) {
    usedMinutes = max(usedMinutes, minute)
  }
}

enum UsageBasedActivityScheduler {
  static let activityPrefix = "UsageBasedBlockingActivity"
  static let activityMinuteTickPrefix = "usageMinuteTick"
  static let thresholdEvent = DeviceActivityEvent.Name("usageAllowanceReached")
  static let warningEventName = DeviceActivityEvent.Name("usageFiveMinutesRemaining")

  private static let stateKey = "usageBasedBlocking.monitoringState"
  private static let statesKey = "usageBasedBlocking.monitoringStates"
  private static let suite = UserDefaults(suiteName: "group.com.inigojv.cntrl")!
  private static let log = Logger(
    subsystem: "com.foqos.monitor",
    category: "UsageBasedActivityScheduler"
  )

  enum ReconcileMode: Equatable {
    case recoverExistingSession(UsageBasedMonitoringState)
    case migrateSameHour(UsageBasedMonitoringState, duplicates: [UsageBasedMonitoringState])
    case transitionToNewHour(UsageBasedMonitoringState)
    case startFresh
    case ambiguousFutureState
  }

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
    allStates.filter { $0.activityName == activity }.last
  }

  static func state(for sessionId: String) -> UsageBasedMonitoringState? {
    let matches = allStates.filter { $0.sessionId == sessionId }
    guard !matches.isEmpty else { return nil }

    let profileIDs = Set(matches.map(\ .profileId))
    if profileIDs.count > 1 {
      log.error("Ambiguous state ownership for sessionId=\(sessionId, privacy: .public): multiple profile IDs found")
      return nil
    }

    return matches.max(by: { $0.windowStart < $1.windowStart })
  }

  static func state(for profileId: UUID) -> UsageBasedMonitoringState? {
    allStates.filter { $0.profileId == profileId }.last
  }

  static func state(
    for profileId: UUID,
    sessionId: String,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) -> UsageBasedMonitoringState? {
    guard let windowStart = hourlyWindow(containing: date, calendar: calendar)?.start else {
      return nil
    }

    return allStates.first {
      $0.profileId == profileId
        && $0.sessionId == sessionId
        && $0.windowStart == windowStart
    }
  }

  private static func isLessPreferredState(
    _ lhs: UsageBasedMonitoringState,
    _ rhs: UsageBasedMonitoringState
  ) -> Bool {
    if lhs.allowanceInMinutes != rhs.allowanceInMinutes {
      return lhs.allowanceInMinutes < rhs.allowanceInMinutes
    }

    if lhs.usedMinutes != rhs.usedMinutes {
      return lhs.usedMinutes < rhs.usedMinutes
    }

    return lhs.sessionId < rhs.sessionId
  }

  static func chooseAuthoritativeState(
    candidates: [UsageBasedMonitoringState],
    preferredSessionId: String? = nil
  ) -> UsageBasedMonitoringState? {
    guard !candidates.isEmpty else { return nil }

    if let preferredSessionId,
      let preferred = candidates.first(where: { $0.sessionId == preferredSessionId })
    {
      let best = candidates.max(by: isLessPreferredState)!
      return isLessPreferredState(preferred, best) ? best : preferred
    }

    return candidates.max(by: isLessPreferredState)
  }

  static func resolveReconcileMode(
    profileId: UUID,
    sessionId: String,
    windowStart: Date,
    states: [UsageBasedMonitoringState]
  ) -> ReconcileMode {
    let profileStates = states.filter { $0.profileId == profileId }
    let sessionStates = profileStates.filter { $0.sessionId == sessionId }

    if let sameSessionSameWindow = sessionStates.first(where: { $0.windowStart == windowStart }) {
      return .recoverExistingSession(sameSessionSameWindow)
    }

    if let latestForSession = sessionStates.max(by: { $0.windowStart < $1.windowStart }) {
      if latestForSession.windowStart < windowStart {
        return .transitionToNewHour(latestForSession)
      }

      return .ambiguousFutureState
    }

    let sameHourProfileStates = profileStates.filter { $0.windowStart == windowStart }
    guard !sameHourProfileStates.isEmpty else {
      return .startFresh
    }

    guard let authoritative = chooseAuthoritativeState(candidates: sameHourProfileStates) else {
      return .startFresh
    }

    let duplicates = sameHourProfileStates.filter {
      !stateIdentityEquals($0, authoritative)
    }
    return .migrateSameHour(authoritative, duplicates: duplicates)
  }

  static func combinedReachedRestrictions(
    for states: [UsageBasedMonitoringState]
  ) -> (
    applicationTokens: Set<ApplicationToken>,
    categoryTokens: Set<ActivityCategoryToken>,
    webDomainTokens: Set<WebDomainToken>
  ) {
    let applicationTokens = Set(states.flatMap { $0.applicationTokens })
    let categoryTokens = Set(states.flatMap { $0.categoryTokens })
    let webDomainTokens = Set(states.flatMap { $0.webDomainTokens })
    return (applicationTokens, categoryTokens, webDomainTokens)
  }

  static func usageProgress(
    for state: UsageBasedMonitoringState?,
    isActive: Bool,
    fallbackAllowanceInMinutes: Int = UsageBasedStrategyData.defaultAllowanceInMinutes
  ) -> Double {
    guard isActive, let state else { return 0 }
    let total = max(1, state.allowanceInMinutes)
    let used = max(0, min(state.usedMinutes, total))
    return max(0, min(1, Double(used) / Double(total)))
  }

  static func rebuildRestrictions() {
    let reachedStates = allStates.filter { $0.allowanceReached }

    guard !reachedStates.isEmpty else {
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      return
    }

    let combined = combinedReachedRestrictions(for: reachedStates)
    AppBlockerUtil().activateUsageBasedRestrictions(
      applicationTokens: combined.applicationTokens,
      categoryTokens: combined.categoryTokens,
      webDomainTokens: combined.webDomainTokens
    )
  }

  static func profileId(from activity: DeviceActivityName) -> UUID? {
    let components = activity.rawValue.split(separator: ":")
    guard components.count >= 4,
      components[0] == Substring(activityPrefix)
    else {
      return nil
    }
    return UUID(uuidString: String(components[1]))
  }

  static func sessionId(from activity: DeviceActivityName) -> String? {
    let components = activity.rawValue.split(separator: ":")
    guard components.count >= 4,
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

    let mode = resolveReconcileMode(
      profileId: profileId,
      sessionId: sessionId,
      windowStart: window.start,
      states: allStates
    )

    switch mode {
    case .recoverExistingSession(let recovered):
      let center = DeviceActivityCenter()
      if !center.activities.contains(recovered.activityName) {
        try schedule(recovered, window: window, calendar: calendar)
      }

    case .transitionToNewHour(var existingSessionState):
      let center = DeviceActivityCenter()
      center.stopMonitoring([existingSessionState.activityName])
      existingSessionState.beginWindow(at: window.start)
      save(existingSessionState)
      rebuildRestrictions()
      try schedule(existingSessionState, window: window, calendar: calendar)

    case .migrateSameHour(let authoritative, let duplicates):
      if duplicates.count > 0 {
        log.warning(
          "Duplicate same-hour states detected for profile=\(profileId.uuidString, privacy: .public). Migrating authoritative session=\(authoritative.sessionId, privacy: .public) to target session=\(sessionId, privacy: .public)"
        )
      }

      let migrated = UsageBasedMonitoringState(
        profileId: profileId,
        sessionId: sessionId,
        applicationTokens: applicationTokens,
        categoryTokens: categoryTokens,
        webDomainTokens: webDomainTokens,
        baseAllowanceInMinutes: authoritative.baseAllowanceInMinutes,
        allowanceInMinutes: authoritative.allowanceInMinutes,
        enableFiveMinuteWarning: enableFiveMinuteWarning,
        extraTimeInMinutes: extraTimeInMinutes,
        enableExtraTimeReduction: enableExtraTimeReduction,
        extraTimeCooldownInSeconds: extraTimeCooldownInSeconds,
        windowStart: authoritative.windowStart,
        usedMinutes: authoritative.usedMinutes,
        warningSent: authoritative.warningSent,
        allowanceReached: authoritative.allowanceReached,
        extraTimeUsedCount: authoritative.extraTimeUsedCount,
        extraTimeCooldownUntil: authoritative.extraTimeCooldownUntil
      )

      save(migrated)

      let sessionsToClear = Set(([authoritative] + duplicates).map(\ .sessionId)).subtracting([sessionId])
      for obsoleteSessionId in sessionsToClear {
        let obsoleteStates = allStates.filter {
          $0.profileId == profileId
            && $0.windowStart == window.start
            && $0.sessionId == obsoleteSessionId
        }
        for obsolete in obsoleteStates {
          DeviceActivityCenter().stopMonitoring([obsolete.activityName])
        }
        clear(sessionId: obsoleteSessionId)
      }

      rebuildRestrictions()
      try schedule(migrated, window: window, calendar: calendar)

    case .startFresh:
      rebuildRestrictions()
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

    case .ambiguousFutureState:
      log.error(
        "Ambiguous reconciliation for profile=\(profileId.uuidString, privacy: .public), session=\(sessionId, privacy: .public): found future-window state"
      )
      throw UsageBasedActivityError.invalidHourlyWindow
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

    let previousActivity = state.activityName

    let grantAmount = state.grantExtraTime(at: date)
    guard grantAmount > 0 else {
      return nil
    }

    save(state)
    rebuildRestrictions()

    do {
      DeviceActivityCenter().stopMonitoring([previousActivity])
      try schedule(state, window: window, calendar: calendar)
    } catch {
      return nil
    }

    return state
  }

  static func stop(sessionId: String) {
    let center = DeviceActivityCenter()

    let activities = center.activities.filter {
      Self.sessionId(from: $0) == sessionId
    }

    clear(sessionId: sessionId)

    if !activities.isEmpty {
      center.stopMonitoring(activities)
    }

    rebuildRestrictions()
  }

  static func stopDuplicateUsageMonitors(for profileId: UUID, except sessionId: String? = nil) {
    let center = DeviceActivityCenter()
    let usageActivities = center.activities.filter { $0.rawValue.hasPrefix("\(activityPrefix):") }
    let activeSessionIds = Set(allStates.map(\.sessionId))
    let activeActivityNames = Set(allStates.map(\.activityName))

    for activity in usageActivities {
      guard let activityProfileId = Self.profileId(from: activity) else { continue }
      guard let activitySessionId = Self.sessionId(from: activity) else { continue }

      let isSameProfile = activityProfileId == profileId
      let isSameSession = sessionId == activitySessionId
      let isStaleSession = !activeSessionIds.contains(activitySessionId)
      let isStaleActivityIdentity = !activeActivityNames.contains(activity)

      if (isSameProfile && !isSameSession) || isStaleSession || isStaleActivityIdentity {
        center.stopMonitoring([activity])
      }
    }
  }

  static func hourlyWindow(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
    calendar.dateInterval(of: .hour, for: date)
  }

  static func event(for state: UsageBasedMonitoringState) -> DeviceActivityEvent {
    event(for: state, thresholdInMinutes: state.allowanceInMinutes)
  }

  static func warningThresholdMinutes(for state: UsageBasedMonitoringState) -> Int? {
    guard state.enableFiveMinuteWarning, state.allowanceInMinutes > 0 else { return nil }
    let leadInMinutes = 2
    return max(1, state.allowanceInMinutes - leadInMinutes)
  }

  static func warningEvent(for state: UsageBasedMonitoringState) -> DeviceActivityEvent? {
    guard let thresholdInMinutes = warningThresholdMinutes(for: state) else { return nil }
    return event(for: state, thresholdInMinutes: thresholdInMinutes)
  }

  static func minuteTickEventName(for minute: Int) -> DeviceActivityEvent.Name {
    DeviceActivityEvent.Name("\(activityMinuteTickPrefix):\(minute)")
  }

  static func minuteTickMinute(from event: DeviceActivityEvent.Name) -> Int? {
    let raw = event.rawValue
    guard raw.hasPrefix("\(activityMinuteTickPrefix):") else { return nil }
    let suffix = raw.replacingOccurrences(of: "\(activityMinuteTickPrefix):", with: "")
    return Int(suffix)
  }

  static func recordUsageTick(
    minute: Int,
    for activity: DeviceActivityName,
    at date: Date = Date(),
    calendar: Calendar = .current
  ) {
    guard var state = currentState(for: activity),
      let window = hourlyWindow(containing: date, calendar: calendar),
      state.windowStart == window.start
    else {
      return
    }

    state.recordUsageTick(minute: minute)
    save(state)
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
    let center = DeviceActivityCenter()
    let activeUsageActivities = center.activities.filter { $0.rawValue.hasPrefix("\(activityPrefix):") }

    stopDuplicateUsageMonitors(for: state.profileId, except: state.sessionId)

    if !activeUsageActivities.contains(state.activityName) {
      let activityLimit = 5
      let remainingUsageActivities = center.activities.filter { $0.rawValue.hasPrefix("\(activityPrefix):") }
      if remainingUsageActivities.count >= activityLimit {
        throw UsageBasedActivityError.tooManyActivities
      }
    }

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

    let tickMinutes = Set(1...state.allowanceInMinutes)
    let warningThreshold = Self.warningThresholdMinutes(for: state)
    for minute in tickMinutes {
      if minute == state.allowanceInMinutes {
        continue
      }
      if let warningThreshold,
        minute == warningThreshold
      {
        continue
      }
      events[Self.minuteTickEventName(for: minute)] = Self.event(
        for: state,
        thresholdInMinutes: minute
      )
    }

    try center.startMonitoring(
      state.activityName,
      during: schedule,
      events: events
    )
  }

  private static func save(_ state: UsageBasedMonitoringState) {
    var states = allStates
    if let index = states.firstIndex(where: { stateIdentityEquals($0, state) }) {
      states[index] = state
    } else {
      states.append(state)
    }

    guard let data = try? JSONEncoder().encode(states) else { return }
    suite.set(data, forKey: statesKey)
    suite.removeObject(forKey: stateKey)
  }

  private static func stateIdentityEquals(
    _ lhs: UsageBasedMonitoringState,
    _ rhs: UsageBasedMonitoringState
  ) -> Bool {
    lhs.profileId == rhs.profileId
      && lhs.sessionId == rhs.sessionId
      && lhs.windowStart == rhs.windowStart
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
  case tooManyActivities
}

extension UsageBasedActivityError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .invalidHourlyWindow:
      return "The usage window could not be scheduled."
    case .noSelectedActivities:
      return "Select at least one app, category, or website to protect."
    case .tooManyActivities:
      return "This app is already monitoring the maximum number of usage-based activities. Stop one and try again."
    }
  }
}