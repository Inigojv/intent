import Foundation

struct HomePresentationState {
  enum ProfileCreationScope {
    case usageBased
    case onDemand
  }

  enum ProfileListScope {
    case onDemand
    case usageBased
  }

  var isProfileListPresent = false
  var showOnDemandProfileList = false
  var showUsageBasedProfileList = false
  var showNewProfileView = false
  var showGuidedProfileCreationView = false
  var showStartProfilePicker = false
  var showDonationView = false
  var showSettingsView = false
  var showActiveProfileSessionView = false

  var profileCreationScope: ProfileCreationScope?
  var profileListScope: ProfileListScope?

  var profileToEdit: BlockedProfiles?
  var profileToShowStats: BlockedProfiles?
  var dashboardInsightsContext: DashboardInsightsContext?
  var navigateToProfileId: UUID?

  var showingAlert = false
  var alertTitle = ""
  var alertMessage = ""

  var newProfilePreferredStrategyId: String? {
    switch profileCreationScope {
    case .usageBased:
      return UsageBasedBlockingStrategy.id
    case .onDemand, nil:
      return nil
    }
  }

  var newProfileAllowedStrategyIds: [String]? {
    switch profileCreationScope {
    case .usageBased:
      return [UsageBasedBlockingStrategy.id]
    case .onDemand, nil:
      return StrategyManager.nonUsageBasedStrategies.map { $0.getIdentifier() }
    }
  }
}
