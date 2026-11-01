import Foundation

struct UsageBasedStrategyData: Codable, Equatable {
  static let defaultAllowanceInMinutes = 20
  static let defaultDisableCountdownInSeconds = 5
  static let defaultExtraTimeInMinutes = 0
  static let defaultExtraTimeReductionEnabled = false
  static let defaultExtraTimeCooldownInSeconds = 0
  static let defaultFiveMinuteWarningEnabled = true
  static let allowanceRangeInMinutes = 5...60
  static let extraTimeRangeInMinutes = 0...30
  static let disableCountdownRangeInSeconds = 5...60
  static let extraTimeCooldownRangeInSeconds = 0...60

  var allowanceInMinutes: Int
  var enableFiveMinuteWarning: Bool
  var disableCountdownInSeconds: Int
  var extraTimeInMinutes: Int
  var enableExtraTimeReduction: Bool
  var extraTimeCooldownInSeconds: Int

  init(
    allowanceInMinutes: Int,
    enableFiveMinuteWarning: Bool = defaultFiveMinuteWarningEnabled,
    disableCountdownInSeconds: Int = defaultDisableCountdownInSeconds,
    extraTimeInMinutes: Int = defaultExtraTimeInMinutes,
    enableExtraTimeReduction: Bool = defaultExtraTimeReductionEnabled,
    extraTimeCooldownInSeconds: Int = defaultExtraTimeCooldownInSeconds
  ) {
    self.allowanceInMinutes = allowanceInMinutes
    self.enableFiveMinuteWarning = enableFiveMinuteWarning
    self.disableCountdownInSeconds = disableCountdownInSeconds
    self.extraTimeInMinutes = extraTimeInMinutes
    self.enableExtraTimeReduction = enableExtraTimeReduction
    self.extraTimeCooldownInSeconds = extraTimeCooldownInSeconds
  }

  private enum CodingKeys: String, CodingKey {
    case allowanceInMinutes
    case enableFiveMinuteWarning
    case disableCountdownInSeconds
    case extraTimeInMinutes
    case enableExtraTimeReduction
    case extraTimeCooldownInSeconds
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
    extraTimeInMinutes = try container.decodeIfPresent(
      Int.self,
      forKey: .extraTimeInMinutes
    ) ?? Self.defaultExtraTimeInMinutes
    enableExtraTimeReduction = try container.decodeIfPresent(
      Bool.self,
      forKey: .enableExtraTimeReduction
    ) ?? Self.defaultExtraTimeReductionEnabled
    extraTimeCooldownInSeconds = try container.decodeIfPresent(
      Int.self,
      forKey: .extraTimeCooldownInSeconds
    ) ?? Self.defaultExtraTimeCooldownInSeconds
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
    let clampedExtraTime = extraTimeInMinutes == 0
      ? 0
      : min(
        max(extraTimeInMinutes, Self.extraTimeRangeInMinutes.lowerBound),
        Self.extraTimeRangeInMinutes.upperBound
      )
    let clampedExtraCooldown = extraTimeCooldownInSeconds == 0
      ? 0
      : min(
        max(extraTimeCooldownInSeconds, Self.extraTimeCooldownRangeInSeconds.lowerBound),
        Self.extraTimeCooldownRangeInSeconds.upperBound
      )

    return UsageBasedStrategyData(
      allowanceInMinutes: normalizedValue,
      enableFiveMinuteWarning: enableFiveMinuteWarning,
      disableCountdownInSeconds: clampedCountdown,
      extraTimeInMinutes: clampedExtraTime,
      enableExtraTimeReduction: enableExtraTimeReduction,
      extraTimeCooldownInSeconds: clampedExtraCooldown
    )
  }
}