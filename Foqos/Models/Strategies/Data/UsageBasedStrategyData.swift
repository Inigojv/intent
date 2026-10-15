import Foundation

struct UsageBasedStrategyData: Codable, Equatable {
  static let defaultAllowanceInMinutes = 20
  static let allowanceRangeInMinutes = 1...59

  var allowanceInMinutes: Int

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
      )
    )
  }
}