import Foundation

struct UsageBasedStrategyData: Codable, Equatable {
  static let defaultAllowanceInMinutes = 20
  static let defaultDisableCountdownInSeconds = 5
  static let defaultFiveMinuteWarningEnabled = true
  static let allowanceRangeInMinutes = 5...60
  static let disableCountdownRangeInSeconds = 5...60

  var allowanceInMinutes: Int
  var enableFiveMinuteWarning: Bool
  var disableCountdownInSeconds: Int

  init(
    allowanceInMinutes: Int,
    enableFiveMinuteWarning: Bool = defaultFiveMinuteWarningEnabled,
    disableCountdownInSeconds: Int = defaultDisableCountdownInSeconds
  ) {
    self.allowanceInMinutes = allowanceInMinutes
    self.enableFiveMinuteWarning = enableFiveMinuteWarning
    self.disableCountdownInSeconds = disableCountdownInSeconds
  }

  private enum CodingKeys: String, CodingKey {
    case allowanceInMinutes
    case enableFiveMinuteWarning
    case disableCountdownInSeconds
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    allowanceInMinutes = try container.decode(Int.self, forKey: .allowanceInMinutes)
    enableFiveMinuteWarning = try container.decodeIfPresent(
      Bool.self,
      forKey: .enableFiveMinuteWarning
    ) ?? Self.defaultFiveMinuteWarningEnabled
    disableCountdownInSeconds = try container.decodeIfPresent(
      Int.self,
      forKey: .disableCountdownInSeconds
    ) ?? Self.defaultDisableCountdownInSeconds
  }

  static func decode(_ data: Data?) -> UsageBasedStrategyData {
    guard let data,
      let configuration = try? JSONDecoder().decode(UsageBasedStrategyData.self, from: data)
    else {
      return UsageBasedStrategyData(allowanceInMinutes: defaultAllowanceInMinutes)
    }

    return configuration.normalized
  }

  static func encode(_ configuration: UsageBasedStrategyData) -> Data? {
    try? JSONEncoder().encode(configuration.normalized)
  }

  private var normalized: UsageBasedStrategyData {
    let clamped = min(
      max(allowanceInMinutes, Self.allowanceRangeInMinutes.lowerBound),
      Self.allowanceRangeInMinutes.upperBound
    )
    let rounded = Int((Double(clamped) / 5.0).rounded(.toNearestOrAwayFromZero) * 5.0)
    let normalizedValue = min(
      max(rounded, Self.allowanceRangeInMinutes.lowerBound),
      Self.allowanceRangeInMinutes.upperBound
    )

    let clampedCountdown = min(
      max(disableCountdownInSeconds, Self.disableCountdownRangeInSeconds.lowerBound),
      Self.disableCountdownRangeInSeconds.upperBound
    )

    return UsageBasedStrategyData(
      allowanceInMinutes: normalizedValue,
      enableFiveMinuteWarning: enableFiveMinuteWarning,
      disableCountdownInSeconds: clampedCountdown
    )
  }
}