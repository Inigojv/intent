import Foundation

struct UsageBasedStrategyData: Codable, Equatable {
  static let defaultAllowanceInMinutes = 20
  static let defaultFiveMinuteWarningEnabled = true
  static let allowanceRangeInMinutes = 1...59

  var allowanceInMinutes: Int
  var enableFiveMinuteWarning: Bool

  init(
    allowanceInMinutes: Int,
    enableFiveMinuteWarning: Bool = defaultFiveMinuteWarningEnabled
  ) {
    self.allowanceInMinutes = allowanceInMinutes
    self.enableFiveMinuteWarning = enableFiveMinuteWarning
  }

  private enum CodingKeys: String, CodingKey {
    case allowanceInMinutes
    case enableFiveMinuteWarning
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    allowanceInMinutes = try container.decode(Int.self, forKey: .allowanceInMinutes)
    enableFiveMinuteWarning = try container.decodeIfPresent(
      Bool.self,
      forKey: .enableFiveMinuteWarning
    ) ?? Self.defaultFiveMinuteWarningEnabled
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
    UsageBasedStrategyData(
      allowanceInMinutes: min(
        max(allowanceInMinutes, Self.allowanceRangeInMinutes.lowerBound),
        Self.allowanceRangeInMinutes.upperBound
      ),
      enableFiveMinuteWarning: enableFiveMinuteWarning
    )
  }
}