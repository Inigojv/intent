import DeviceActivity
import ManagedSettings
import XCTest

@testable import foqos

final class UsageBasedBlockingTests: XCTestCase {
  func testConfigurationRoundTripsAndClampsAllowance() {
    let encoded = UsageBasedStrategyData.encode(
      UsageBasedStrategyData(allowanceInMinutes: 75, enableFiveMinuteWarning: false)
    )

    XCTAssertEqual(
      UsageBasedStrategyData.decode(encoded).allowanceInMinutes,
      UsageBasedStrategyData.allowanceRangeInMinutes.upperBound
    )
    XCTAssertFalse(UsageBasedStrategyData.decode(encoded).enableFiveMinuteWarning)
  }

  func testConfigurationRoundsAllowanceToFiveMinuteSteps() {
    let encoded = UsageBasedStrategyData.encode(
      UsageBasedStrategyData(allowanceInMinutes: 7, enableFiveMinuteWarning: false)
    )

    XCTAssertEqual(UsageBasedStrategyData.decode(encoded).allowanceInMinutes, 10)

    let encodedHigh = UsageBasedStrategyData.encode(
      UsageBasedStrategyData(allowanceInMinutes: 58, enableFiveMinuteWarning: false)
    )

    XCTAssertEqual(
      UsageBasedStrategyData.decode(encodedHigh).allowanceInMinutes,
      UsageBasedStrategyData.allowanceRangeInMinutes.upperBound
    )
  }

  func testConfigurationUsesDefaultAllowanceWhenMissing() {
    XCTAssertEqual(
      UsageBasedStrategyData.decode(nil).allowanceInMinutes,
      UsageBasedStrategyData.defaultAllowanceInMinutes
    )
  }

  func testConfigurationDefaultsWarningOnWhenDecodingOlderData() throws {
    let oldData = Data(#"{"allowanceInMinutes":30}"#.utf8)

    let configuration = UsageBasedStrategyData.decode(oldData)

    XCTAssertEqual(configuration.allowanceInMinutes, 30)
    XCTAssertTrue(configuration.enableFiveMinuteWarning)
  }

  func testHourlyWindowUsesClockHourBoundaries() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-15T14:45:00Z"))

    let window = try XCTUnwrap(
      UsageBasedActivityScheduler.hourlyWindow(containing: date, calendar: calendar)
    )

    XCTAssertEqual(window.start, ISO8601DateFormatter().date(from: "2026-10-15T14:00:00Z"))
    XCTAssertEqual(window.end, ISO8601DateFormatter().date(from: "2026-10-15T15:00:00Z"))
  }

  func testScheduledMonitoringRejectsAnEmptySelection() {
    XCTAssertThrowsError(
      try UsageBasedActivityScheduler.start(
        profileId: UUID(),
        sessionId: UUID().uuidString,
        applicationTokens: [],
        categoryTokens: [],
        webDomainTokens: [],
        allowanceInMinutes: 20
      )
    )
  }

  func testActivityNameChangesForEachClockHour() {
    let profileId = UUID()
    let sessionId = UUID().uuidString
    let start = Date(timeIntervalSince1970: 1_000_000)
    let firstState = makeState(profileId: profileId, sessionId: sessionId, windowStart: start)
    var nextState = firstState
    nextState.windowStart = start.addingTimeInterval(60 * 60)

    XCTAssertNotEqual(firstState.activityName, nextState.activityName)
  }

  func testActivityNameIdentifiesItsOwningSession() {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000)
    )

    XCTAssertEqual(
      UsageBasedActivityScheduler.sessionId(from: state.activityName),
      state.sessionId
    )
    XCTAssertNil(
      UsageBasedActivityScheduler.sessionId(
        from: DeviceActivityName(rawValue: "UsageBasedBlockingActivity:malformed")
      )
    )
  }

  func testUsageEventUsesAllowanceAndIncludesPastHourlyActivity() {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 20
    )

    let event = UsageBasedActivityScheduler.event(for: state)

    XCTAssertEqual(event.threshold, DateComponents(minute: 20))
    XCTAssertTrue(event.includesPastActivity)
  }

  func testWarningEventFiresAboutTwoMinutesBeforeAllowance() {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 20
    )

    XCTAssertEqual(
      UsageBasedActivityScheduler.warningEvent(for: state)?.threshold,
      DateComponents(minute: 18)
    )
  }

  func testWarningEventUsesATwoMinuteLeadForShortAllowances() {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 5
    )

    XCTAssertEqual(
      UsageBasedActivityScheduler.warningEvent(for: state)?.threshold,
      DateComponents(minute: 3)
    )
  }

  func testWarningIsOnlyMarkedOnceUntilTheNextWindow() {
    var state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000)
    )

    XCTAssertTrue(state.markWarningSent())
    XCTAssertFalse(state.markWarningSent())
    XCTAssertTrue(state.markAllowanceReached())

    state.beginWindow(at: state.windowStart.addingTimeInterval(60 * 60))

    XCTAssertFalse(state.warningSent)
    XCTAssertFalse(state.allowanceReached)
    XCTAssertTrue(state.markWarningSent())
  }

  func testLateWarningIsSuppressedAfterAllowanceIsReached() {
    var state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000)
    )

    XCTAssertTrue(state.markAllowanceReached())
    XCTAssertFalse(state.markWarningSent())
  }

  func testAllowanceOfFiveMinutesUsesATwoMinuteWarning() {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 5
    )

    XCTAssertEqual(
      UsageBasedActivityScheduler.warningEvent(for: state)?.threshold,
      DateComponents(minute: 3)
    )
  }

  func testDisabledWarningDoesNotCreateWarningEvent() {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      enableFiveMinuteWarning: false
    )

    XCTAssertNil(UsageBasedActivityScheduler.warningEvent(for: state))
  }

  func testStopDelaySecondsAreCappedAtFiveSecondsMinimumWhenEnabled() {
    XCTAssertEqual(BlockedProfiles.normalizedStopDelayInSeconds(0), 0)
    XCTAssertEqual(BlockedProfiles.normalizedStopDelayInSeconds(1), 5)
    XCTAssertEqual(BlockedProfiles.normalizedStopDelayInSeconds(4), 5)
    XCTAssertEqual(BlockedProfiles.normalizedStopDelayInSeconds(5), 5)
    XCTAssertEqual(BlockedProfiles.normalizedStopDelayInSeconds(60), 60)
  }

  func testMonitoringStatePersistsItsPeriodAndAllowance() throws {
    var state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 35
    )
    XCTAssertTrue(state.markWarningSent())

    let data = try JSONEncoder().encode(state)
    let restoredState = try JSONDecoder().decode(UsageBasedMonitoringState.self, from: data)

    XCTAssertEqual(restoredState, state)
  }

  func testCombinedReachedRestrictionsUnionsAllActiveProfiles() {
    let socialToken = ManagedSettings.Application(bundleIdentifier: "com.example.social").token!
    let newsToken = ManagedSettings.Application(bundleIdentifier: "com.example.news").token!

    let firstState = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      applicationTokens: [socialToken],
      categoryTokens: [],
      webDomainTokens: []
    )
    let secondState = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_100),
      applicationTokens: [newsToken],
      categoryTokens: [],
      webDomainTokens: []
    )

    var firstReached = firstState
    var secondReached = secondState
    firstReached.allowanceReached = true
    secondReached.allowanceReached = true

    let combined = UsageBasedActivityScheduler.combinedReachedRestrictions(
      for: [firstReached, secondReached]
    )
    let expected = Set([socialToken, newsToken])

    XCTAssertEqual(combined.applicationTokens, expected)
    XCTAssertEqual(combined.applicationTokens.count, 2)
  }

  func testUsageProgressStartsAtZeroUntilAProfileIsActive() {
    let activeState = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 20,
      applicationTokens: []
    )
    var inFlightState = activeState
    inFlightState.usedMinutes = 8

    XCTAssertEqual(
      UsageBasedActivityScheduler.usageProgress(
        for: inFlightState,
        isActive: true,
        fallbackAllowanceInMinutes: 20
      ),
      0.4,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      UsageBasedActivityScheduler.usageProgress(
        for: inFlightState,
        isActive: false,
        fallbackAllowanceInMinutes: 20
      ),
      0,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      UsageBasedActivityScheduler.usageProgress(
        for: nil,
        isActive: true,
        fallbackAllowanceInMinutes: 20
      ),
      0,
      accuracy: 0.0001
    )
  }

  private func makeState(
    profileId: UUID,
    sessionId: String,
    windowStart: Date,
    allowanceInMinutes: Int = 20,
    enableFiveMinuteWarning: Bool = true,
    applicationTokens: Set<ApplicationToken> = [],
    categoryTokens: Set<ActivityCategoryToken> = [],
    webDomainTokens: Set<WebDomainToken> = []
  ) -> UsageBasedMonitoringState {
    UsageBasedMonitoringState(
      profileId: profileId,
      sessionId: sessionId,
      applicationTokens: applicationTokens,
      categoryTokens: categoryTokens,
      webDomainTokens: webDomainTokens,
      allowanceInMinutes: allowanceInMinutes,
      enableFiveMinuteWarning: enableFiveMinuteWarning,
      windowStart: windowStart
    )
  }
}