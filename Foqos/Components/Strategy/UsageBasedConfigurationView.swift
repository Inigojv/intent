import SwiftUI

struct UsageBasedConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var themeManager: ThemeManager

  let profileName: String
  let actionTitle: String
  let onSave: (UsageBasedStrategyData) -> Void

  @State private var allowanceInMinutes: Double
  @State private var extraTimeEnabled: Bool
  @State private var extraTimeInMinutes: Double
  @State private var enableExtraTimeReduction: Bool
  @State private var extraTimeCooldownInSeconds: Double
  @State private var isSliding = false

  private let minMinutes: Double = 5
  private let maxMinutes: Double = 60
  private let stepMinutes: Double = 5
  private let extraTimeMinMinutes: Double = 1
  private let extraTimeMaxMinutes: Double = 30
  private let extraTimeCooldownMinSeconds: Double = 5
  private let extraTimeCooldownMaxSeconds: Double = 60
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
    _extraTimeEnabled = State(
      initialValue: initialConfiguration.extraTimeInMinutes > 0 || initialConfiguration.enableExtraTimeReduction || initialConfiguration.extraTimeCooldownInSeconds > 0
    )
    _extraTimeInMinutes = State(
      initialValue: Double(initialConfiguration.extraTimeInMinutes)
    )
    _enableExtraTimeReduction = State(
      initialValue: initialConfiguration.enableExtraTimeReduction
    )
    _extraTimeCooldownInSeconds = State(
      initialValue: Double(initialConfiguration.extraTimeCooldownInSeconds)
    )
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
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

            VStack(spacing: 0) {
              Divider()

              HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                  Text("Allow extra time")

                  Text("Let this profile extend the session briefly when the limit is reached")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $extraTimeEnabled)
                  .labelsHidden()
                  .toggleStyle(.switch)
                  .tint(themeManager.themeColor)
              }
              .padding(.vertical, 12)

              if extraTimeEnabled {
                VStack(alignment: .leading, spacing: 12) {
                  HStack {
                    Text("Extra time amount")
                    Spacer()
                    Text("\(Int(extraTimeInMinutes))m")
                      .font(.system(size: 18, weight: .semibold))
                  }

                  Slider(
                    value: $extraTimeInMinutes,
                    in: extraTimeMinMinutes...extraTimeMaxMinutes,
                    step: 1
                  )
                  .tint(themeManager.themeColor)
                }
                .padding(.vertical, 12)

                HStack(alignment: .top, spacing: 16) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Reduce each time")

                    Text("Lower the extra-time allowance after each use")
                      .font(.subheadline)
                      .foregroundColor(.secondary)
                  }

                  Spacer()

                  Toggle("", isOn: $enableExtraTimeReduction)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(themeManager.themeColor)
                }
                .padding(.vertical, 12)

                HStack(alignment: .top, spacing: 16) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Wait before extra time")

                    Text("Delay before more extra time can be used")
                      .font(.subheadline)
                      .foregroundColor(.secondary)
                  }

                  Spacer()

                  Toggle(
                    "",
                    isOn: Binding(
                      get: { extraTimeCooldownInSeconds > 0 },
                      set: { newValue in
                        if newValue {
                          extraTimeCooldownInSeconds = max(extraTimeCooldownInSeconds, extraTimeCooldownMinSeconds)
                        } else {
                          extraTimeCooldownInSeconds = 0
                        }
                      }
                    )
                  )
                  .labelsHidden()
                  .toggleStyle(.switch)
                  .tint(themeManager.themeColor)
                }
                .padding(.vertical, 12)

                if extraTimeCooldownInSeconds > 0 {
                  VStack(alignment: .leading, spacing: 12) {
                    HStack {
                      Text("Wait time")
                      Spacer()
                      Text("\(Int(extraTimeCooldownInSeconds))s")
                        .font(.system(size: 18, weight: .semibold))
                    }

                    Slider(
                      value: $extraTimeCooldownInSeconds,
                      in: extraTimeCooldownMinSeconds...extraTimeCooldownMaxSeconds,
                      step: 1
                    )
                    .tint(themeManager.themeColor)
                  }
                  .padding(.vertical, 12)
                }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)
          .padding(.top, 28)
          .padding(.bottom, 16)
        }

        ActionButton(
          title: actionTitle,
          backgroundColor: themeManager.themeColor,
          iconName: "checkmark.circle.fill"
        ) {
          let finalAllowance = Int(round(allowanceInMinutes / stepMinutes) * stepMinutes)
          let normalizedAllowance = min(max(finalAllowance, Int(minMinutes)), Int(maxMinutes))
          let normalizedExtraTime = Int(round(extraTimeInMinutes))
          let normalizedCooldown = Int(round(extraTimeCooldownInSeconds))

          onSave(
            UsageBasedStrategyData(
              allowanceInMinutes: normalizedAllowance,
              enableFiveMinuteWarning: NotificationPreferences.allowanceWarningEnabled,
              extraTimeInMinutes: extraTimeEnabled ? normalizedExtraTime : 0,
              enableExtraTimeReduction: extraTimeEnabled && enableExtraTimeReduction,
              extraTimeCooldownInSeconds: extraTimeEnabled ? normalizedCooldown : 0
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