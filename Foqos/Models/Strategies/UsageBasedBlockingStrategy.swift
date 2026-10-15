import FamilyControls
import SwiftData
import SwiftUI

final class UsageBasedBlockingStrategy: BlockingStrategy {
  static let id = "UsageBasedBlockingStrategy"

  var name = "Usage-Based Blocking"
  var description = "Use selected apps for a set number of minutes each clock hour."
  var color: Color = .orange
  var pickerCategory: BlockingStrategyPickerCategory = .moreOptions

  var startsManually = true
  var allowsTimedBreaks = false
  var supportsAllowMode = false

  var onSessionCreation: ((SessionStatus) -> Void)?
  var onErrorMessage: ((String) -> Void)?

  private let appBlocker = AppBlockerUtil()

  func getIdentifier() -> String {
    Self.id
  }

  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)? {
    guard hasSelectedActivities(profile.selectedActivity) else {
      onErrorMessage?("Select at least one app, category, or website to protect.")
      return nil
    }

    if !profile.shouldAskForStartSettings {
      startSession(
        context: context,
        profile: profile,
        configuration: UsageBasedStrategyData.decode(profile.strategyData),
        forceStart: forceStart ?? false
      )
      return nil
    }

    return UsageBasedConfigurationView(
      profileName: profile.name,
      initialConfiguration: UsageBasedStrategyData.decode(profile.strategyData)
    ) { configuration in
      guard let data = UsageBasedStrategyData.encode(configuration) else {
        self.onErrorMessage?("Failed to save the hourly usage allowance.")
        return
      }

      profile.strategyData = data
      profile.updatedAt = Date()

      do {
        try context.save()
      } catch {
        self.onErrorMessage?("Failed to save the hourly usage allowance.")
        return
      }

      BlockedProfiles.updateSnapshot(for: profile)
      self.startSession(
        context: context,
        profile: profile,
        configuration: configuration,
        forceStart: forceStart ?? false
      )
    }
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
    session.endSession()
    try? context.save()
    onSessionCreation?(.ended(session.blockedProfile))
    return nil
  }

  private func startSession(
    context: ModelContext,
    profile: BlockedProfiles,
    configuration: UsageBasedStrategyData,
    forceStart: Bool
  ) {
    appBlocker.deactivateUsageBasedRestrictions()
    if configuration.enableFiveMinuteWarning && configuration.allowanceInMinutes > 5 {
      UsageBasedNotificationScheduler.requestAuthorization()
    }

    let session = BlockedProfileSession.createSession(
      in: context,
      withTag: Self.id,
      withProfile: profile,
      forceStart: forceStart
    )

    do {
      try UsageBasedActivityScheduler.start(
        profileId: profile.id,
        sessionId: session.id,
        applicationTokens: profile.selectedActivity.applicationTokens,
        categoryTokens: profile.selectedActivity.categoryTokens,
        webDomainTokens: profile.selectedActivity.webDomainTokens,
        allowanceInMinutes: configuration.allowanceInMinutes,
        enableFiveMinuteWarning: configuration.enableFiveMinuteWarning
      )
      onSessionCreation?(.started(session))
    } catch {
      session.endSession()
      try? context.save()
      onErrorMessage?("Failed to start hourly usage monitoring: \(error.localizedDescription)")
    }
  }

  private func hasSelectedActivities(_ selection: FamilyActivitySelection) -> Bool {
    !selection.applicationTokens.isEmpty
      || !selection.categoryTokens.isEmpty
      || !selection.webDomainTokens.isEmpty
  }
}