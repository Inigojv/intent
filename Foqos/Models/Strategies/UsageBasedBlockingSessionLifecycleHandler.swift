import Foundation

struct UsageBasedBlockingSessionLifecycleHandler: BlockingSessionLifecycleHandler {
  func sessionDidStart(_ context: BlockingSessionLifecycleContext) {}

  func sessionDidEnd(_ context: BlockingSessionLifecycleContext) {
    guard context.strategyId == UsageBasedBlockingStrategy.id else { return }

    guard let state = UsageBasedActivityScheduler.currentState else {
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      return
    }
    guard state.sessionId == context.sessionId else { return }

    UsageBasedActivityScheduler.stop(sessionId: context.sessionId)
    AppBlockerUtil().deactivateUsageBasedRestrictions()
  }
}