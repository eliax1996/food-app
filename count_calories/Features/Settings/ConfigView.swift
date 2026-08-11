import SwiftData
import SwiftUI
import os

struct ConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var reminderPreferences = ReminderPreferences.stored()
    @State private var notificationAuthorizationState = ReminderAuthorizationState.notDetermined
    @State private var errorMessage: String?

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Planning") {
                    if let profile {
                        NavigationLink {
                            PlanSettingsView(profile: profile)
                        } label: {
                            SettingsSummaryRow(
                                title: "Plan",
                                systemImage: "target",
                                value: "\(profile.dailyCalorieGoal.formatted()) kcal",
                                detail: "\(profile.planGoalSource == .calculated ? "Calculated estimate" : "Manual goal") · Target \(weightText(planTargetWeight(profile)))"
                            )
                        }
                        .accessibilityIdentifier("settings-plan-link")

                        NavigationLink {
                            ProfileSettingsView(profile: profile)
                        } label: {
                            SettingsSummaryRow(
                                title: "Profile",
                                systemImage: "person.crop.circle",
                                value: "Age \(profile.age)",
                                detail: profile.storedCalculatedPlan.map {
                                    "\($0.plan.input.activityLevel.title) routine · On device"
                                } ?? "Saved on this device"
                            )
                        }
                        .accessibilityIdentifier("settings-profile-link")
                    } else {
                        HStack {
                            ProgressView()
                            Text("Preparing profile")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        ReminderSettingsView(
                            preferences: reminderPreferences,
                            authorizationState: notificationAuthorizationState
                        ) { preferences, authorization in
                            reminderPreferences = preferences
                            notificationAuthorizationState = authorization
                        }
                    } label: {
                        SettingsSummaryRow(
                            title: "Reminders",
                            systemImage: "bell",
                            value: reminderValue,
                            detail: reminderDetail
                        )
                    }
                    .accessibilityIdentifier("settings-reminders-link")
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Meal, water, and weight reminders stay independent. Notification access is requested only after you save a reminder.")
                }

                Section("Privacy") {
                    Label("Profile and logs stay on this device", systemImage: "lock")
                        .foregroundStyle(.primary)
                    Text("Count Calories sends only food search and barcode queries to Open Food Facts. Plan calculations and reminder schedules run on device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .accessibilityIdentifier("settings-root")
            .onAppear {
                ensureProfile()
                reminderPreferences = .stored()
                synchronizeReminders()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                reminderPreferences = .stored()
                synchronizeReminders()
            }
            .alert("Could not complete action", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var reminderValue: String {
        guard reminderPreferences.enabledCount > 0 else { return "Off" }
        if notificationAuthorizationState == .denied {
            return "Needs access"
        }
        return "\(reminderPreferences.enabledCount) selected"
    }

    private var reminderDetail: String {
        guard reminderPreferences.enabledCount > 0 else {
            return "Choose meal times, water, or weight"
        }
        switch notificationAuthorizationState {
        case .authorized:
            return "Notification delivery allowed"
        case .notDetermined:
            return "Notification access not requested"
        case .denied:
            return "Selections saved · delivery off"
        }
    }

    private func ensureProfile() {
        guard profile == nil else { return }
        modelContext.insert(UserProfile())
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error(
                "Failed to create settings profile: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = "Profile settings could not be prepared. Try again."
        }
    }

    private func synchronizeReminders() {
        let preferences = ReminderPreferences.stored()
        let mealRecords = entries.map {
            MealReminderRecord(mealType: $0.mealType, date: $0.date)
        }
        let waterRecords = waterDays.map {
            WaterReminderRecord(
                date: $0.date,
                glasses: $0.glasses,
                lastRecordedAt: $0.lastRecordedAt
            )
        }
        let weightRecords = weights.map { WeightReminderRecord(date: $0.date) }

        Task {
            notificationAuthorizationState = await ReminderNotificationManager.shared.authorizationState()
            await ReminderNotificationManager.shared.reschedule(
                meals: mealRecords,
                water: waterRecords,
                weights: weightRecords,
                preferences: preferences
            )
        }
    }
}

private struct SettingsSummaryRow: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                    Spacer(minLength: 12)
                    Text(value)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value), \(detail)")
    }
}

private func planTargetWeight(_ profile: UserProfile) -> Double {
    if profile.planGoalSource == .calculated,
       let stored = profile.storedCalculatedPlan {
        return stored.plan.input.targetWeightKilograms
    }
    return profile.targetWeight
}

private func weightText(_ kilograms: Double) -> String {
    guard kilograms.isFinite, kilograms > 0 else { return "not set" }
    return "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
}

#if DEBUG
#Preview("Settings") {
    ConfigView()
        .modelContainer(PreviewData.makeContainer())
}
#endif
