import SwiftUI

struct UsageBasedConfigurationView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var themeManager: ThemeManager

  let profileName: String
  let actionTitle: String
  let onSave: (UsageBasedStrategyData) -> Void

  @State private var allowanceInMinutes: Int
  @State private var enableFiveMinuteWarning: Bool

  init(
    profileName: String,
    initialConfiguration: UsageBasedStrategyData,
    actionTitle: String = "Start Blocking",
    onSave: @escaping (UsageBasedStrategyData) -> Void
  ) {
    self.profileName = profileName
    self.actionTitle = actionTitle
    self.onSave = onSave
    _allowanceInMinutes = State(initialValue: initialConfiguration.allowanceInMinutes)
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

          Stepper(value: $allowanceInMinutes, in: UsageBasedStrategyData.allowanceRangeInMinutes) {
            HStack(alignment: .firstTextBaseline) {
              Text("\(allowanceInMinutes)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

              Text(allowanceInMinutes == 1 ? "minute per hour" : "minutes per hour")
                .foregroundColor(.secondary)
            }
          }
          .sensoryFeedback(.selection, trigger: allowanceInMinutes)

          Toggle("5-minute warning", isOn: $enableFiveMinuteWarning)
            .tint(themeManager.themeColor)

          if allowanceInMinutes <= 5 {
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
          if enableFiveMinuteWarning && allowanceInMinutes > 5 {
            UsageBasedNotificationScheduler.requestAuthorization()
          }
          onSave(
            UsageBasedStrategyData(
              allowanceInMinutes: allowanceInMinutes,
              enableFiveMinuteWarning: enableFiveMinuteWarning
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
}

#Preview {
  UsageBasedConfigurationView(
    profileName: "Deep Work",
    initialConfiguration: UsageBasedStrategyData(allowanceInMinutes: 20),
    onSave: { _ in }
  )
  .environmentObject(ThemeManager.shared)
}