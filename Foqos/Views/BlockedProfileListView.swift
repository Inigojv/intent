import FamilyControls
import SwiftData
import SwiftUI

private enum ProfileCreationDestination: Identifiable {
  case guided
  case advanced
  case usageBased

  var id: String {
    switch self {
    case .guided:
      return "guided"
    case .advanced:
      return "advanced"
    case .usageBased:
      return "usageBased"
    }
  }
}

struct BlockedProfileListView: View {
  enum ListType {
    case onDemand
    case usageBased
  }

  let listType: ListType
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @Query(sort: [
    SortDescriptor(\BlockedProfiles.order, order: .forward),
    SortDescriptor(\BlockedProfiles.createdAt, order: .reverse),
  ]) private var profiles: [BlockedProfiles]

  @Query(
    filter: #Predicate<BlockedProfileSession> { $0.endTime == nil },
    sort: \BlockedProfileSession.startTime,
    order: .reverse
  ) private var activeSessions: [BlockedProfileSession]

  @State private var profileCreationDestination: ProfileCreationDestination?
  @State private var showingDataExport = false

  private var filteredProfiles: [BlockedProfiles] {
    switch listType {
    case .onDemand:
      return profiles.filter { $0.blockingStrategyId != UsageBasedBlockingStrategy.id }
    case .usageBased:
      return profiles.filter { $0.blockingStrategyId == UsageBasedBlockingStrategy.id }
    }
  }

  @State private var profileToEdit: BlockedProfiles?
  @State private var showErrorAlert = false
  @State private var errorAlertTitle = "Cannot Delete Active Profile"
  @State private var errorAlertMessage =
    "You cannot delete a profile that is currently active. Please switch to a different profile first."
  @State private var editMode: EditMode = .inactive

  var body: some View {
    NavigationStack {
      Group {
        if filteredProfiles.isEmpty {
          ScrollView {
            VStack {
              Spacer(minLength: 70)

              if listType == .usageBased {
                VStack(spacing: 18) {
                  Text("No allowances yet")
                    .font(.title2.weight(.semibold))

                  Button {
                    if canCreateProfiles { profileCreationDestination = .usageBased }
                  } label: {
                    Label("New Allowance", systemImage: "plus")
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 12)
                      .background(Color.accentColor)
                      .foregroundStyle(.white)
                      .clipShape(RoundedRectangle(cornerRadius: 12))
                  }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
              } else {
                Welcome(
                  onGuidedTap: {
                    if canCreateProfiles {
                      profileCreationDestination = .guided
                    }
                  },
                  onAdvancedTap: {
                    if canCreateProfiles {
                      profileCreationDestination = .advanced
                    }
                  }
                )
              }

              Spacer(minLength: 70)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
          }
        } else {
          List {
            ForEach(filteredProfiles) { profile in
              ProfileRow(profile: profile, isActive: profile.id == activeSessionProfileId)
                .contentShape(Rectangle())
                .onTapGesture {
                  if editMode == .inactive {
                    if isUsageProfileEditLocked(profile) {
                      presentUsageEditLockedAlert()
                      return
                    }
                    profileToEdit = profile
                  }
                }
            }
            .onDelete(perform: editMode == .active ? deleteProfiles : nil)
            .onMove(perform: editMode == .active ? moveProfiles : nil)
          }
          .environment(\.editMode, $editMode)
        }
      }
      .navigationTitle(listType == .usageBased ? "Usage-Based" : "Profiles")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
          }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
          if editMode == .active {
            Button(action: { editMode = .inactive }) {
              Image(systemName: "checkmark.circle")
            }
          }
          if !filteredProfiles.isEmpty {
            Menu {
              Button {
                editMode = .active
              } label: {
                Label("Edit/Move", systemImage: "pencil")
              }

              Button {
                showingDataExport = true
              } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
            }
          }
          if canCreateProfiles {
            if listType == .usageBased {
              Button {
                profileCreationDestination = .usageBased
              } label: {
                Image(systemName: "plus")
              }
            } else {
              Menu {
                Button {
                  profileCreationDestination = .guided
                } label: {
                  Label("Guided Setup", systemImage: "list.bullet.clipboard")
                }

                Button {
                  profileCreationDestination = .advanced
                } label: {
                  Label("Full Profile Editor", systemImage: "slider.horizontal.3")
                }
              } label: {
                Image(systemName: "plus")
              }
            }
          }
        }
      }
      .sheet(item: $profileCreationDestination) { destination in
        switch destination {
        case .guided:
          GuidedBlockedProfileCreationView()
        case .advanced:
          BlockedProfileView()
        case .usageBased:
          BlockedProfileView(
            profile: nil,
            preferredStrategyId: UsageBasedBlockingStrategy.id,
            allowedStrategyIds: [UsageBasedBlockingStrategy.id]
          )
        }
      }
      .sheet(item: $profileToEdit) { profile in
        BlockedProfileView(
          profile: profile,
          allowedStrategyIds: listType == .usageBased
            ? [UsageBasedBlockingStrategy.id]
            : nil
        )
      }
      .sheet(isPresented: $showingDataExport) {
        BlockedProfileDataExportView()
      }
      .alert(
        errorAlertTitle,
        isPresented: $showErrorAlert
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorAlertMessage)
      }
    }
  }

  private var activeSessionProfileId: UUID? {
    activeSessions.first?.blockedProfile.id
  }

  private var canCreateProfiles: Bool {
    if listType == .usageBased {
      return true
    }
    return activeSessionProfileId == nil
  }

  private func isUsageProfileEditLocked(_ profile: BlockedProfiles) -> Bool {
    guard profile.blockingStrategyId == UsageBasedBlockingStrategy.id else {
      return false
    }

    return UsageBasedStrategyData.decode(profile.strategyData).isAllowanceEnabled
  }

  private func presentUsageEditLockedAlert() {
    errorAlertTitle = "Disable Allowance To Edit"
    errorAlertMessage = "Disable this usage-based allowance before editing it."
    showErrorAlert = true
  }

  private func presentDeleteActiveProfileAlert() {
    errorAlertTitle = "Cannot Delete Active Profile"
    errorAlertMessage =
      "You cannot delete a profile that is currently active. Please switch to a different profile first."
    showErrorAlert = true
  }

  private func deleteProfiles(at offsets: IndexSet) {
    let activeSession = BlockedProfileSession.mostRecentActiveSession(
      in: context)

    // Check if any of the profiles to delete are active
    for index in offsets {
      let profile = profiles[index]
      if profile.id == activeSession?.blockedProfile.id {
        presentDeleteActiveProfileAlert()
        return
      }
    }

    // Delete the profiles and reorder
    do {
      for index in offsets {
        let profile = profiles[index]
        try BlockedProfiles.deleteProfile(profile, in: context)
      }

      // Reorder remaining profiles to fix gaps in ordering
      let remainingProfiles = try BlockedProfiles.fetchProfiles(in: context)
      try BlockedProfiles.reorderProfiles(remainingProfiles, in: context)
    } catch {
      print("Failed to delete or reorder profiles: \(error)")
    }
  }

  private func moveProfiles(from source: IndexSet, to destination: Int) {
    var reorderedProfiles = Array(profiles)
    reorderedProfiles.move(fromOffsets: source, toOffset: destination)

    do {
      try BlockedProfiles.reorderProfiles(reorderedProfiles, in: context)
    } catch {
      print("Failed to reorder profiles: \(error)")
    }
  }
}

#Preview {
  BlockedProfileListView(listType: .onDemand)
    .modelContainer(for: BlockedProfiles.self, inMemory: true)
}
