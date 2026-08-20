import SwiftData
import SwiftUI
import os

private enum ConfigPresentation: Identifiable {
    case calculatedSetup(CaloriePlanSetupRecord)

    var id: String { "calculated-setup" }
}

struct ConfigView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    @State private var reminderPreferences = ReminderPreferences.stored()
    @State private var notificationAuthorizationState = ReminderAuthorizationState.notDetermined
    @State private var presentation: ConfigPresentation?
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
                                detail: "\(planGoalSourceSummary(profile.planGoalSource)) · Target \(weightText(planTargetWeight(profile)))"
                            )
                        }
                        .accessibilityIdentifier("settings-plan-link")

                        NavigationLink {
                            AdaptivePlanView(
                                profile: profile,
                                onReviewCalculatedSetup: beginCalculatedSetup
                            )
                        } label: {
                            SettingsSummaryRow(
                                title: "Goal check-ins",
                                systemImage: "checkmark.circle",
                                value: adaptivePlanSummary(profile),
                                detail: "Review food logs and weights before any goal change"
                            )
                        }
                        .accessibilityIdentifier("settings-goal-check-ins-link")

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

                    NavigationLink {
                        MealDescriptionDataView()
                    } label: {
                        SettingsSummaryRow(
                            title: "Meal Description & Draft Data",
                            systemImage: "text.bubble",
                            value: "On device",
                            detail: "Learned choices and saved draft controls"
                        )
                    }
                    .accessibilityIdentifier("settings-meal-description-data-link")

                    Text("Meal descriptions, dictation, plan calculations, and reminder schedules run on device. Count Calories sends only individual food search and barcode queries to Open Food Facts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .accessibilityIdentifier("settings-root")
            .sheet(item: $presentation) { presentation in
                switch presentation {
                case .calculatedSetup(let record):
                    CaloriePlanSetupView(profile: profile, record: record) {
                        self.presentation = nil
                    }
                }
            }
            .onAppear {
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

    private func beginCalculatedSetup() {
        guard let profile else { return }
        let loadedRecord = CaloriePlanSetupStore.load(profileExists: true)
        let storedRecord = CaloriePlanSetupStore.reconciledAfterAcceptedCalculation(
            loadedRecord,
            acceptedPlanDate: profile.storedCalculatedPlan?.acceptedAt
        )
        if storedRecord != loadedRecord {
            CaloriePlanSetupStore.save(storedRecord)
        }
        let record = storedRecord.status == .inProgress
            ? storedRecord
            : CaloriePlanSetupRecord(
                status: .inProgress,
                draft: .prefilled(from: profile),
                acceptedPlanDateAtStart: profile.storedCalculatedPlan?.acceptedAt
            )
        presentation = .calculatedSetup(record)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let systemImage: String
    let value: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                if dynamicTypeSize.isAccessibilitySize {
                    Text(title)
                    Text(value)
                        .foregroundStyle(.secondary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
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
    if profile.planGoalSource == .calculated || profile.planGoalSource == .adapted,
       let stored = profile.storedCalculatedPlan {
        return stored.plan.input.targetWeightKilograms
    }
    return profile.targetWeight
}

private func weightText(_ kilograms: Double) -> String {
    guard kilograms.isFinite, kilograms > 0 else { return "not set" }
    return "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
}

#if DEBUG || RELEASE_VALIDATION
#Preview("Settings") {
    ConfigView()
        .previewPlanEvidenceContainer(PreviewData.makeContainer())
}
#endif
