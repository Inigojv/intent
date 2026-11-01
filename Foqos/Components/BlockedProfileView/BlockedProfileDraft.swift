import FamilyControls
import Foundation
import SwiftData
import SwiftUI

final class BlockedProfileDraft: ObservableObject {
  @Published var name: String
  @Published var enableLiveActivity: Bool
  @Published var enableReminder: Bool
  @Published var enableBreaks: Bool
  @Published var breakTimeInMinutes: Int
  @Published var allowMultipleBreaks: Bool
  @Published var enableStrictMode: Bool
  @Published var enableBlockAppInstallation: Bool
  @Published var reminderTimeInMinutes: Int
  @Published var customReminderMessage: String
  @Published var enableAllowMode: Bool
  @Published var enableAllowModeDomain: Bool
  @Published var enableSafariBlocking: Bool
  @Published var enableAdultContentBlocking: Bool
  @Published var disableBackgroundStops: Bool
  @Published var enableHardMode: Bool
  @Published var hardModeDurationInMinutes: Int
  @Published var stopDelayInSeconds: Int
  @Published var enableEmergencyUnblock: Bool
  @Published var domains: [String]
  @Published var physicalUnblockItems: [PhysicalUnblockItem]
  @Published var schedule: BlockedProfileSchedule
  @Published var selectedActivity: FamilyActivitySelection
  @Published var strategyData: Data?
  @Published var askForStartSettings: Bool
  @Published var selectedStrategy: BlockingStrategy? {
    didSet {
      let oldSettingsKind = StrategyStartSettingsKind(strategy: oldValue)
      let newSettingsKind = StrategyStartSettingsKind(strategy: selectedStrategy)

      if selectedStrategy?.getIdentifier() == UsageBasedBlockingStrategy.id {
        askForStartSettings = false
      } else if newSettingsKind == nil || oldSettingsKind != newSettingsKind {
        strategyData = nil
        askForStartSettings = true
      }

      enforceStrategyPolicies()
    }
  }

  init(profile: BlockedProfiles? = nil, preferredStrategyId: String? = nil) {
    name = profile?.name ?? ""
    selectedActivity = profile?.selectedActivity ?? FamilyActivitySelection()
    enableLiveActivity = profile?.enableLiveActivity ?? false
    enableBreaks = profile?.enableBreaks ?? false
    breakTimeInMinutes = profile?.breakTimeInMinutes ?? 15
    allowMultipleBreaks = profile?.allowMultipleBreaks ?? false
    enableStrictMode = profile?.enableStrictMode ?? false
    enableBlockAppInstallation = profile?.enableBlockAppInstallation ?? false
    enableAllowMode = profile?.enableAllowMode ?? false
    enableAllowModeDomain = profile?.enableAllowModeDomains ?? false
    enableSafariBlocking = profile?.enableSafariBlocking ?? true
    enableAdultContentBlocking = profile?.enableAdultContentBlocking ?? false
    enableReminder = profile?.reminderTimeInSeconds != nil
    disableBackgroundStops = profile?.disableBackgroundStops ?? false
    enableEmergencyUnblock = profile?.enableEmergencyUnblock ?? true
    enableHardMode = profile?.enableHardMode ?? false
    hardModeDurationInMinutes = profile?.hardModeDurationInMinutes ?? 30
    stopDelayInSeconds = max(0, min(60, profile?.stopDelayInSeconds ?? 0))
    reminderTimeInMinutes = Int(profile?.reminderTimeInSeconds ?? 900) / 60
    customReminderMessage = profile?.customReminderMessage ?? ""
    domains = profile?.domains ?? []
    physicalUnblockItems = profile?.physicalUnblockItems ?? []
    strategyData = nil
    askForStartSettings = true
    schedule =
      profile?.schedule
      ?? BlockedProfileSchedule(
        days: [],
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        updatedAt: Date()
      )

    if let profileStrategyId = profile?.blockingStrategyId {
      selectedStrategy = StrategyManager.getStrategyFromId(id: profileStrategyId)
    } else if let preferredStrategyId,
      let preferredStrategy = StrategyManager.availableStrategies.first(
        where: { $0.getIdentifier() == preferredStrategyId }
      )
    {
      selectedStrategy = preferredStrategy
    } else if let fallbackStrategy = StrategyManager.nonUsageBasedStrategies.first {
      selectedStrategy = fallbackStrategy
    } else {
      selectedStrategy = NFCBlockingStrategy()
    }

    if selectedStrategy?.getIdentifier() == UsageBasedBlockingStrategy.id {
      askForStartSettings = false
    }

    // Restore persisted settings after the strategy observer has handled initial selection.
    strategyData = profile?.strategyData
    askForStartSettings =
      selectedStrategy?.getIdentifier() == UsageBasedBlockingStrategy.id
      ? false
      : (profile?.askForStartSettings ?? askForStartSettings)

    enforceStrategyPolicies()
  }

  var isValid: Bool {
    return !name.isEmpty
  }

  var selectedStrategyAllowsTimedBreaks: Bool {
    return selectedStrategy?.allowsTimedBreaks ?? true
  }

  var selectedStrategyAllowsHardMode: Bool {
    !(selectedStrategy?.hasTimer ?? false)
  }

  var selectedStrategySupportsAllowMode: Bool {
    return selectedStrategy?.supportsAllowMode ?? true
  }

  func save(
    existingProfile: BlockedProfiles?,
    in context: ModelContext
  ) throws -> BlockedProfiles {
    ensureSavedStartSettings()
    if selectedStrategy?.getIdentifier() == UsageBasedBlockingStrategy.id {
      askForStartSettings = false
    }
    schedule.updatedAt = Date()

    let reminderTimeSeconds: UInt32? =
      enableReminder ? UInt32(reminderTimeInMinutes * 60) : nil
    let physicalUnblockItemsToSave: [PhysicalUnblockItem]? =
      physicalUnblockItems.isEmpty ? nil : physicalUnblockItems
    let enableTimedBreaksToSave = selectedStrategyAllowsTimedBreaks && enableBreaks

    if let existingProfile {
      let updatedProfile = try BlockedProfiles.updateProfile(
        existingProfile,
        in: context,
        name: name,
        selection: selectedActivity,
        blockingStrategyId: selectedStrategy?.getIdentifier(),
        strategyData: .some(strategyData),
        askForStartSettings: askForStartSettings,
        enableLiveActivity: enableLiveActivity,
        reminderTime: reminderTimeSeconds,
        customReminderMessage: customReminderMessage,
        enableBreaks: enableTimedBreaksToSave,
        breakTimeInMinutes: breakTimeInMinutes,
        allowMultipleBreaks: enableTimedBreaksToSave && allowMultipleBreaks,
        enableStrictMode: enableStrictMode,
        enableBlockAppInstallation: enableBlockAppInstallation,
        enableAllowMode: enableAllowMode,
        enableAllowModeDomains: enableAllowModeDomain,
        enableSafariBlocking: enableSafariBlocking,
        enableAdultContentBlocking: enableAdultContentBlocking,
        domains: domains,
        physicalUnblockItems: .some(physicalUnblockItemsToSave),
        schedule: schedule,
        disableBackgroundStops: disableBackgroundStops,
        enableEmergencyUnblock: enableEmergencyUnblock,
        enableHardMode: selectedStrategyAllowsHardMode && enableHardMode,
        hardModeDurationInMinutes: hardModeDurationInMinutes,
        stopDelayInSeconds: stopDelayInSeconds
      )

      DeviceActivityCenterUtil.scheduleTimerActivity(for: updatedProfile)
      return updatedProfile
    }

    let newProfile = try BlockedProfiles.createProfile(
      in: context,
      name: name,
      selection: selectedActivity,
      blockingStrategyId: selectedStrategy?.getIdentifier() ?? NFCBlockingStrategy.id,
      strategyData: strategyData,
      askForStartSettings: askForStartSettings,
      enableLiveActivity: enableLiveActivity,
      reminderTimeInSeconds: reminderTimeSeconds,
      customReminderMessage: customReminderMessage,
      enableBreaks: enableTimedBreaksToSave,
      breakTimeInMinutes: breakTimeInMinutes,
      allowMultipleBreaks: enableTimedBreaksToSave && allowMultipleBreaks,
      enableStrictMode: enableStrictMode,
      enableBlockAppInstallation: enableBlockAppInstallation,
      enableAllowMode: enableAllowMode,
      enableAllowModeDomains: enableAllowModeDomain,
      enableSafariBlocking: enableSafariBlocking,
      enableAdultContentBlocking: enableAdultContentBlocking,
      domains: domains,
      physicalUnblockItems: physicalUnblockItemsToSave,
      schedule: schedule,
      disableBackgroundStops: disableBackgroundStops,
      enableEmergencyUnblock: enableEmergencyUnblock,
      enableHardMode: selectedStrategyAllowsHardMode && enableHardMode,
      hardModeDurationInMinutes: hardModeDurationInMinutes,
      stopDelayInSeconds: stopDelayInSeconds
    )

    DeviceActivityCenterUtil.scheduleTimerActivity(for: newProfile)
    return newProfile
  }

  private func enforceStrategyPolicies() {
    if !selectedStrategyAllowsHardMode {
      enableHardMode = false
    }

    if !selectedStrategyAllowsTimedBreaks {
      enableBreaks = false
      allowMultipleBreaks = false
    }

    if !selectedStrategySupportsAllowMode && enableAllowMode {
      enableAllowMode = false
      selectedActivity = FamilyActivitySelection()
    }
  }

  private func ensureSavedStartSettings() {
    guard !askForStartSettings, strategyData == nil,
      let settingsKind = StrategyStartSettingsKind(strategy: selectedStrategy)
    else {
      return
    }

    strategyData = settingsKind.defaultData
  }
}
