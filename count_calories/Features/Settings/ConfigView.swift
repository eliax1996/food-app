import SwiftData
import SwiftUI
import os

struct ConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]

    @AppStorage(ReminderPreferenceKey.breakfast) private var breakfastReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.lunch) private var lunchReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.snack) private var snackReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.dinner) private var dinnerReminderEnabled = false
    @AppStorage(ReminderPreferenceKey.water) private var waterReminderEnabled = false

    @State private var targetWeight = 68.0
    @State private var age = 30
    @State private var dailyGoal = 1700
    @State private var targetDate = Date.now.addingTimeInterval(60 * 60 * 24 * 90)
    @State private var notificationAuthorizationState = ReminderAuthorizationState.notDetermined
    @State private var errorMessage: String?

    init() {}

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    Stepper("Age: \(age)", value: $age, in: 1...120)
                }

                Section("Goal") {
                    HStack {
                        TextField("Target weight", value: $targetWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }

                    Stepper("Daily goal: \(dailyGoal) kcal", value: $dailyGoal, in: 800...5000, step: 50)
                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                }

                Section {
                    reminderToggle(
                        "Breakfast",
                        detail: "9:00 AM when not logged",
                        isOn: $breakfastReminderEnabled,
                        identifier: "breakfast-reminder-toggle"
                    )
                    reminderToggle(
                        "Lunch",
                        detail: "1:00 PM when not logged",
                        isOn: $lunchReminderEnabled,
                        identifier: "lunch-reminder-toggle"
                    )
                    reminderToggle(
                        "Snack",
                        detail: "4:00 PM when not logged",
                        isOn: $snackReminderEnabled,
                        identifier: "snack-reminder-toggle"
                    )
                    reminderToggle(
                        "Dinner",
                        detail: "8:00 PM when not logged",
                        isOn: $dinnerReminderEnabled,
                        identifier: "dinner-reminder-toggle"
                    )
                } header: {
                    Text("Food reminders")
                } footer: {
                    Text("Each reminder is removed for that day as soon as you register its meal.")
                }

                Section {
                    reminderToggle(
                        "Water",
                        detail: "After 2 hours without a glass",
                        isOn: $waterReminderEnabled,
                        identifier: "water-reminder-toggle"
                    )
                } header: {
                    Text("Water reminders")
                } footer: {
                    Text("Water reminders run from 8:00 AM to 10:00 PM and stop after 8 glasses.")
                }

                if notificationAuthorizationState == .denied,
                   let systemSettingsURL = ReminderNotificationManager.systemSettingsURL {
                    Section {
                        Button {
                            openURL(systemSettingsURL)
                        } label: {
                            Label("Open notification settings", systemImage: "bell.slash.fill")
                        }
                    } header: {
                        Text("Notification access")
                    } footer: {
                        Text("Enabled reminders cannot arrive until notifications are allowed in Settings.")
                    }
                }

                Section {
                    Button("Save settings", action: saveSettings)
                        .disabled(targetWeight <= 0 || age <= 0 || dailyGoal <= 0)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadProfile()
                synchronizeReminders(requestAuthorization: false)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                synchronizeReminders(requestAuthorization: false)
            }
            .onChange(of: breakfastReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: lunchReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: snackReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: dinnerReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .onChange(of: waterReminderEnabled) { _, enabled in
                synchronizeReminders(requestAuthorization: enabled)
            }
            .alert("Could not complete action", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func reminderToggle(
        _ title: String,
        detail: String,
        isOn: Binding<Bool>,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private func synchronizeReminders(requestAuthorization: Bool) {
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

        Task {
            if requestAuthorization {
                do {
                    _ = try await ReminderNotificationManager.shared.requestAuthorizationIfNeeded()
                } catch {
                    errorMessage = "Notification access could not be requested. Please try again."
                }
            }

            notificationAuthorizationState = await ReminderNotificationManager.shared.authorizationState()
            await ReminderNotificationManager.shared.reschedule(
                meals: mealRecords,
                water: waterRecords,
                preferences: .stored()
            )
        }
    }

    private func loadProfile() {
        let currentProfile = profile ?? createProfile()
        targetWeight = currentProfile.targetWeight
        age = currentProfile.age
        dailyGoal = currentProfile.dailyCalorieGoal
        targetDate = currentProfile.targetDate
    }

    private func createProfile() -> UserProfile {
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        saveChanges()
        return newProfile
    }

    private func saveSettings() {
        let currentProfile = profile ?? createProfile()
        currentProfile.targetWeight = targetWeight
        currentProfile.age = age
        currentProfile.dailyCalorieGoal = dailyGoal
        currentProfile.targetDate = targetDate
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistence.error("Failed to save settings: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your settings could not be saved. Please try again."
        }
    }
}

#if DEBUG
#Preview("Settings") {
    ConfigView()
        .modelContainer(PreviewData.makeContainer())
}
#endif
