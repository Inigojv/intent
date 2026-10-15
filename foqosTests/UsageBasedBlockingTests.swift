import DeviceActivity
import XCTest

@testable import foqos

final class UsageBasedBlockingTests: XCTestCase {
  func testConfigurationRoundTripsAndClampsAllowance() {
    let encoded = UsageBasedStrategyData.encode(
      UsageBasedStrategyData(allowanceInMinutes: 75)
    )

    XCTAssertEqual(
      UsageBasedStrategyData.decode(encoded).allowanceInMinutes,
      UsageBasedStrategyData.allowanceRangeInMinutes.upperBound
    )
  }

  func testConfigurationUsesDefaultAllowanceWhenMissing() {
    XCTAssertEqual(
      UsageBasedStrategyData.decode(nil).allowanceInMinutes,
      UsageBasedStrategyData.defaultAllowanceInMinutes
    )
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

  func testActivityNameChangesForEachClockHour() {
    let profileId = UUID()
    let sessionId = UUID().uuidString
    let start = Date(timeIntervalSince1970: 1_000_000)
    let firstState = makeState(profileId: profileId, sessionId: sessionId, windowStart: start)
    var nextState = firstState
    nextState.windowStart = start.addingTimeInterval(60 * 60)

    XCTAssertNotEqual(firstState.activityName, nextState.activityName)
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

  func testMonitoringStatePersistsItsPeriodAndAllowance() throws {
    let state = makeState(
      profileId: UUID(),
      sessionId: UUID().uuidString,
      windowStart: Date(timeIntervalSince1970: 1_000_000),
      allowanceInMinutes: 35
    )

    let data = try JSONEncoder().encode(state)
    let restoredState = try JSONDecoder().decode(UsageBasedMonitoringState.self, from: data)

    XCTAssertEqual(restoredState, state)
  }

  private func makeState(
    profileId: UUID,
    sessionId: String,
    windowStart: Date,
    allowanceInMinutes: Int = 20
  ) -> UsageBasedMonitoringState {
    UsageBasedMonitoringState(
      profileId: profileId,
      sessionId: sessionId,
      applicationTokens: [],
      categoryTokens: [],
      webDomainTokens: [],
      allowanceInMinutes: allowanceInMinutes,
      windowStart: windowStart
    )
  }
}