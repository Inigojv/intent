import Foundation

struct UsageBasedBlockingSessionLifecycleHandler: BlockingSessionLifecycleHandler {
  func sessionDidStart(_ context: BlockingSessionLifecycleContext) {
    guard
      context.strategyId == UsageBasedBlockingStrategy.id,
      UsageBasedActivityScheduler.currentState?.sessionId == context.sessionId
    else {
      if let state = UsageBasedActivityScheduler.currentState {
        UsageBasedActivityScheduler.stop(sessionId: state.sessionId)
      }
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      return
    }
  }

  func sessionDidEnd(_ context: BlockingSessionLifecycleContext) {
    guard let state = UsageBasedActivityScheduler.currentState else {
      guard context.strategyId == UsageBasedBlockingStrategy.id else { return }
      UsageBasedActivityScheduler.stop(sessionId: context.sessionId)
      AppBlockerUtil().deactivateUsageBasedRestrictions()
      return
    }
    guard state.sessionId == context.sessionId else { return }

    UsageBasedActivityScheduler.stop(sessionId: context.sessionId)
    AppBlockerUtil().deactivateUsageBasedRestrictions()
  }
}