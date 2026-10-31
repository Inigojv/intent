import SwiftUI

struct UsageBasedConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var themeManager: ThemeManager

  let profileName: String
  let actionTitle: String
  let onSave: (UsageBasedStrategyData) -> Void

  @State private var allowanceInMinutes: Double
  @State private var disableCountdownInSeconds: Double
  @State private var enableFiveMinuteWarning: Bool
  @State private var isSliding = false

  private let minMinutes: Double = 5
  private let maxMinutes: Double = 60
  private let stepMinutes: Double = 5
  private let snapPoints: [Double] = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]
  private let snapThreshold: Double = 3

  init(
    profileName: String,
    initialConfiguration: UsageBasedStrategyData,
    actionTitle: String = "Start Blocking",
    onSave: @escaping (UsageBasedStrategyData) -> Void
  ) {
    self.profileName = profileName
    self.actionTitle = actionTitle
    self.onSave = onSave
    _allowanceInMinutes = State(initialValue: Double(initialConfiguration.allowanceInMinutes))
    _disableCountdownInSeconds = State(
      initialValue: Double(initialConfiguration.disableCountdownInSeconds)
    )
    _enableFiveMinuteWarning = State(
      initialValue: initialConfiguration.enableFiveMinuteWarning
    )
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Usage Allowance")
              .font(.title2.bold())

            Text("Choose how many minutes of selected app use are allowed each clock hour.")
              .font(.callout)
              .foregroundColor(.secondary)
          }

          VStack(spacing: 16) {
            timeDisplay
            sliderControls
          }

          Toggle("5 minute warning notification", isOn: $enableFiveMinuteWarning)
            .tint(themeManager.themeColor)

          VStack(alignment: .leading, spacing: 10) {
            Text("Time before disable")
              .font(.headline)

            Text("Choose how long the unlock delay lasts before the app disables this strategy.")
              .font(.callout)
              .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
              Text("\(Int(disableCountdownInSeconds))s")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
              Text("before disable")
                .foregroundColor(.secondary)
            }

            Slider(
              value: $disableCountdownInSeconds,
              in: 5...60,
              step: 1,
              onEditingChanged: { _ in }
            )
            .tint(themeManager.themeColor)
          }

          if Int(allowanceInMinutes) <= 5 {
            Text("A warning requires an allowance of at least 6 minutes.")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 28)

        Spacer(minLength: 24)

        ActionButton(
          title: actionTitle,
          backgroundColor: themeManager.themeColor,
          iconName: "checkmark.circle.fill"
        ) {
          let finalAllowance = Int(round(allowanceInMinutes / stepMinutes) * stepMinutes)
          let normalizedAllowance = min(max(finalAllowance, Int(minMinutes)), Int(maxMinutes))
          let normalizedCountdown = Int(disableCountdownInSeconds.rounded())

          if enableFiveMinuteWarning && normalizedAllowance > 5 {
            UsageBasedNotificationScheduler.requestAuthorization()
          }
          onSave(
            UsageBasedStrategyData(
              allowanceInMinutes: normalizedAllowance,
              enableFiveMinuteWarning: enableFiveMinuteWarning,
              disableCountdownInSeconds: normalizedCountdown
            )
          )
          dismiss()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
          }
          .accessibilityLabel("Cancel")
        }
      }
    }
  }

  private var timeDisplay: some View {
    VStack(spacing: 8) {
      Text("\(Int(allowanceInMinutes))")
        .font(.system(size: 52, weight: .bold, design: .rounded))
        .contentTransition(.numericText())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: allowanceInMinutes)

      Text(Int(allowanceInMinutes) == 1 ? "minute per hour" : "minutes per hour")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }

  private var sliderControls: some View {
    HStack(spacing: 16) {
      Button {
        decrementAllowance()
      } label: {
        Image(systemName: "minus.circle.fill")
          .font(.system(size: 32))
          .foregroundColor(allowanceInMinutes > minMinutes ? themeManager.themeColor : .gray)
      }
      .disabled(allowanceInMinutes <= minMinutes)
      .scaleEffect(allowanceInMinutes <= minMinutes ? 0.9 : 1.0)
      .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: allowanceInMinutes)

      VStack(spacing: 8) {
        Slider(
          value: $allowanceInMinutes,
          in: minMinutes...maxMinutes,
          step: stepMinutes,
          onEditingChanged: { editing in
            isSliding = editing
            if !editing {
              snapToNearestPreset()
            }
          }
        )
        .tint(themeManager.themeColor)
        .sensoryFeedback(.selection, trigger: allowanceInMinutes)

        HStack {
          Text("5m")
            .font(.caption2)
            .foregroundColor(.secondary)
          Spacer()
          Text("1h")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }

      Button {
        incrementAllowance()
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 32))
          .foregroundColor(allowanceInMinutes < maxMinutes ? themeManager.themeColor : .gray)
      }
      .disabled(allowanceInMinutes >= maxMinutes)
      .scaleEffect(allowanceInMinutes >= maxMinutes ? 0.9 : 1.0)
      .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: allowanceInMinutes)
    }
  }

  private func incrementAllowance() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      allowanceInMinutes = min(allowanceInMinutes + stepMinutes, maxMinutes)
    }
  }

  private func decrementAllowance() {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
      allowanceInMinutes = max(allowanceInMinutes - stepMinutes, minMinutes)
    }
  }

  private func snapToNearestPreset() {
    if let closest = snapPoints.min(by: { abs($0 - allowanceInMinutes) < abs($1 - allowanceInMinutes) }) {
      let distance = abs(closest - allowanceInMinutes)
      if distance <= snapThreshold {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
          allowanceInMinutes = closest
        }
      }
    }
  }
}

#Preview {
  UsageBasedConfigurationView(
    profileName: "Deep Work",
    initialConfiguration: UsageBasedStrategyData(allowanceInMinutes: 20),
    onSave: { _ in }
  )
  .environmentObject(ThemeManager.shared)
}