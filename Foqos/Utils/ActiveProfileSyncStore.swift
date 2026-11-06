import Foundation
import OSLog

enum ActiveProfileSyncStore {
  private static let log = Logger(
    subsystem: "com.inigojv.cntrl", category: "ActiveProfileSync")

  static func publish(
    session: SharedData.SessionSnapshot?,
    profile: SharedData.ProfileSnapshot?
  ) {
    // Mac sync has been retired from the app. Keep the hook but do not publish any active profile sync state.
    let record = ActiveProfileSyncRecord(
      profileId: nil,
      profileName: nil,
      sessionId: nil,
      domains: [],
      domainMode: .block,
      state: .inactive,
      updatedAt: Date()
    )

    do {
      let data = try JSONEncoder().encode(record)
      let store = NSUbiquitousKeyValueStore.default
      store.set(data, forKey: ActiveProfileSyncRecord.storeKey)
      _ = store.synchronize()
      log.info("Profile sync disabled for this app build.")
    } catch {
      log.error("Could not encode the profile sync record")
    }
  }

  private static func state(
    for session: SharedData.SessionSnapshot,
    profile: SharedData.ProfileSnapshot
  ) -> ActiveProfileSyncRecord.State {
    if session.pauseStartTime != nil && session.pauseEndTime == nil {
      return .paused
    }

    if profile.enableBreaks,
      profile.blockingStrategyId != SoftUnblockSessionLifecycleHandler.nfcStrategyId,
      profile.blockingStrategyId != SoftUnblockSessionLifecycleHandler.qrStrategyId,
      session.breakStartTime != nil && session.breakEndTime == nil
    {
      return .breakActive
    }

    return .active
  }
}
