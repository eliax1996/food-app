import SwiftData
import SwiftUI

struct ReminderSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WaterDay.date, order: .reverse) private var waterDays: [WaterDay]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    let onSaved: (ReminderPreferences, ReminderAuthorizationState) -> Void
    private let refreshesAuthorization: Bool

    @State private var preferences: ReminderPreferences
    @State private var authorizationState: ReminderAuthorizationState
    @State private var editorFocus: ReminderEditorFocus?
    @State private var showingMealCustomization = false

    init(
        preferences: ReminderPreferences,
        authorizationState: ReminderAuthorizationState,
        refreshesAuthorization: Bool = true,
        onSaved: @escaping (ReminderPreferences, ReminderAuthorizationState) -> Void
    ) {
        self.onSaved = onSaved
        self.refreshesAuthorization = refreshesAuthorization
        _preferences = State(initialValue: preferences)
        _authorizationState = State(initialValue: authorizationState)
    }

    private var plannedReminders: [ReminderNotificationPlan] {
        ReminderSchedulePlanner.plans(
            now: .now,
            calendar: .current,
            preferences: preferences,
            meals: entries.map {
                MealReminderRecord(mealType: $0.mealType, date: $0.date)
            },
            water: waterDays.map {
                WaterReminderRecord(
                    date: $0.date,
                    glasses: $0.glasses,
                    lastRecordedAt: $0.lastRecordedAt
                )
            },
            weights: weights.map { WeightReminderRecord(date: $0.date) }
        )
    }

    var body: some View {
        List {
            mealSection
            weightSection
            waterSection
            deliverySection
            nextReminderSection
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("reminder-settings")
        .confirmationDialog(
            "Customize Meal Reminders",
            isPresented: $showingMealCustomization,
            titleVisibility: .visible
        ) {
            Button("Enable or Disable Meals") {
                openEditor(focus: .mealAvailability)
            }
            .accessibilityIdentifier("meal-reminders-enable-disable")

            Button("Change Notification Times") {
                openEditor(focus: .mealTimes)
            }
            .accessibilityIdentifier("meal-reminders-change-times")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to change meal availability or notification timing.")
        }
        .sheet(item: $editorFocus) { focus in
            ReminderEditor(
                initialPreferences: preferences,
                authorizationState: authorizationState,
                focus: focus,
                onSave: save
            )
            .interactiveDismissDisabled()
        }
        .task {
            guard refreshesAuthorization else { return }
            await refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard refreshesAuthorization, newPhase == .active else { return }
            Task { await refreshAuthorization() }
        }
    }

    private var mealSection: some View {
        Section {
            ForEach(ReminderMeal.allCases, id: \.self) { meal in
                ReminderStatusSummaryRow(
                    title: meal.rawValue,
                    time: timeText(preferences.time(for: meal)),
                    isEnabled: preferences.isEnabled(meal)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(meal.rawValue) reminder")
                .accessibilityValue("\(timeText(preferences.time(for: meal))), \(preferences.isEnabled(meal) ? "Enabled" : "Disabled")")
                .accessibilityIdentifier("\(meal.identifierComponent)-reminder-summary")
            }

            Button {
                showingMealCustomization = true
            } label: {
                Label("Customize Meal Reminders", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("meal-reminders-customize")
        } header: {
            Text("Meal reminders")
        } footer: {
            Text("Schedules stay visible when disabled. Use Customize Meal Reminders to change which meals are enabled or edit notification times separately. A reminder is omitted when that meal is already logged for the local day.")
        }
    }

    private var weightSection: some View {
        Section {
            Button {
                openEditor(focus: .weight)
            } label: {
                EditableReminderSummaryRow(
                    title: "Schedule",
                    value: preferences.weightEnabled
                        ? "\(weightFrequencyText) · \(timeText(preferences.weightTime))"
                        : "Off"
                )
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weight check-in reminder")
            .accessibilityValue(preferences.weightEnabled
                ? "\(weightFrequencyText), \(timeText(preferences.weightTime))"
                : "Off")
            .accessibilityHint("Opens reminder editor")
            .accessibilityIdentifier("weight-reminder-summary")
        } header: {
            Text("Weight check-in")
        } footer: {
            if preferences.weightEnabled, preferences.weightFrequency == .weekly {
                Text("Weekly reminder waits seven days after the latest recorded weight.")
            } else {
                Text("Consistent readings help reveal trend; one reading never changes your calorie goal.")
            }
        }
    }

    private var waterSection: some View {
        Section {
            Button {
                openEditor(focus: .water)
            } label: {
                EditableReminderSummaryRow(
                    title: "Schedule",
                    value: preferences.waterEnabled ? waterReminderWindowText : "Off"
                )
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Water reminder")
            .accessibilityValue(preferences.waterEnabled
                ? "After 2 hours without a glass, \(waterReminderWindowText)"
                : "Off")
            .accessibilityHint("Opens reminder editor")
            .accessibilityIdentifier("water-reminder-summary")
        } header: {
            Text("Water")
        } footer: {
            if preferences.waterEnabled {
                Text("After two hours without a glass during this daily window; stops at 8 glasses.")
            } else {
                Text("Water reminders use fixed \(waterReminderStartText)–\(waterReminderEndText) hours, every two hours after no glass was logged recently; stop at 8 glasses.")
            }
        }
    }

    @ViewBuilder
    private var deliverySection: some View {
        Section {
            LabeledContent("Notification access", value: authorizationText)
                .accessibilityIdentifier("reminder-authorization-status")

            if authorizationState == .denied,
               let systemSettingsURL = ReminderNotificationManager.systemSettingsURL {
                Button {
                    openURL(systemSettingsURL)
                } label: {
                    Label("Open Notification Settings", systemImage: "bell.slash")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("open-notification-settings")
            }
        } header: {
            Text("Delivery")
        } footer: {
            switch authorizationState {
            case .authorized:
                Text("Selected reminders can be delivered. iOS may delay them for Focus or scheduled summaries.")
            case .notDetermined:
                Text("Access is requested only after you save at least one reminder.")
            case .denied:
                Text("Reminder choices are saved, but no notification can arrive until access is allowed in iOS Settings.")
            }
        }
    }

    @ViewBuilder
    private var nextReminderSection: some View {
        Section("Next selected reminder") {
            if let next = plannedReminders.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(next.kind.title)
                        .font(.body.weight(.medium))
                    Text(next.fireDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("next-reminder")
            } else {
                Text(preferences.hasEnabledReminder ? "No reminder is currently due." : "Turn on a reminder to preview its next time.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weightFrequencyText: String {
        switch preferences.weightFrequency {
        case .daily: "Daily"
        case .weekly: "Weekly"
        }
    }

    private var authorizationText: String {
        switch authorizationState {
        case .authorized: "Allowed"
        case .notDetermined: "Not requested"
        case .denied: "Off in iOS Settings"
        }
    }

    private func openEditor(focus: ReminderEditorFocus) {
        editorFocus = focus
    }

    @MainActor
    private func save(_ draft: ReminderPreferences) async -> String? {
        draft.store()
        preferences = draft

        var requestError: String?
        if draft.hasEnabledReminder {
            do {
                _ = try await ReminderNotificationManager.shared.requestAuthorizationIfNeeded()
            } catch {
                requestError = "Notification access could not be requested. Your reminder choices were saved; try again."
            }
        }

        let state = await ReminderNotificationManager.shared.authorizationState()
        let schedulingResult = await reschedule(preferences: draft)
        authorizationState = state
        onSaved(draft, state)
        if requestError == nil, schedulingResult == .failed {
            requestError = "Your reminder choices were saved, but notifications could not be updated. Previous reminders were kept where possible; try again."
        }
        return requestError
    }

    @MainActor
    private func refreshAuthorization() async {
        let state = await ReminderNotificationManager.shared.authorizationState()
        _ = await reschedule(preferences: preferences)
        authorizationState = state
        onSaved(preferences, state)
    }

    private func reschedule(preferences: ReminderPreferences) async -> ReminderSchedulingResult {
        await ReminderNotificationManager.shared.reschedule(
            meals: entries.map {
                MealReminderRecord(mealType: $0.mealType, date: $0.date)
            },
            water: waterDays.map {
                WaterReminderRecord(
                    date: $0.date,
                    glasses: $0.glasses,
                    lastRecordedAt: $0.lastRecordedAt
                )
            },
            weights: weights.map { WeightReminderRecord(date: $0.date) },
            preferences: preferences
        )
    }
}

private enum ReminderEditorFocus: Identifiable, Equatable {
    case mealAvailability
    case mealTimes
    case weight
    case water

    var id: String {
        switch self {
        case .mealAvailability: "meal-availability"
        case .mealTimes: "meal-times"
        case .weight: "weight"
        case .water: "water"
        }
    }

    var title: String {
        switch self {
        case .mealAvailability: "Meal Reminders"
        case .mealTimes: "Notification Times"
        case .weight: "Edit Weight Reminder"
        case .water: "Edit Water Reminder"
        }
    }

    var editorIdentifier: String {
        switch self {
        case .mealAvailability: "reminder-editor-meals"
        case .mealTimes: "reminder-editor-meal-times"
        case .weight: "reminder-editor-weight"
        case .water: "reminder-editor-water"
        }
    }
}

private struct ReminderStatusSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let time: String
    let isEnabled: Bool

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(time)
                        .monospacedDigit()
                    Text(isEnabled ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Text(title)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(time)
                            .monospacedDigit()
                        Text(isEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct EditableReminderSummaryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let value: String

    var body: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(value)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
            if dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
}

private struct ReminderEditor: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss

    let authorizationState: ReminderAuthorizationState
    let focus: ReminderEditorFocus
    let onSave: (ReminderPreferences) async -> String?

    @State private var draft: ReminderPreferences
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        initialPreferences: ReminderPreferences,
        authorizationState: ReminderAuthorizationState,
        focus: ReminderEditorFocus = .mealAvailability,
        onSave: @escaping (ReminderPreferences) async -> String?
    ) {
        self.authorizationState = authorizationState
        self.focus = focus
        self.onSave = onSave
        _draft = State(initialValue: initialPreferences)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                if showsMeals {
                    Section {
                        ForEach(mealsToEdit, id: \.self) { meal in
                            if focus == .mealAvailability {
                                Toggle(meal.rawValue, isOn: enabledBinding(for: meal))
                                    .accessibilityIdentifier("\(meal.identifierComponent)-reminder-toggle")
                            } else {
                                DatePicker(
                                    meal.rawValue,
                                    selection: timeBinding(for: meal),
                                    displayedComponents: .hourAndMinute
                                )
                                .accessibilityIdentifier("\(meal.identifierComponent)-reminder-time")
                            }
                        }
                    } header: {
                        Text(focus == .mealAvailability ? "Enabled meals" : "Meal notification times")
                    } footer: {
                        Text(focus == .mealAvailability
                             ? "Each meal can be enabled independently. Its saved notification time stays unchanged when disabled."
                             : "Changing a time does not enable or disable that meal. Reminders are omitted when the matching meal is already logged.")
                    }
                    .id("reminder-editor-meals")
                }

                if showsWeight {
                    Section {
                        Toggle("Weight check-in", isOn: $draft.weightEnabled)
                            .accessibilityIdentifier("weight-reminder-toggle")
                        if draft.weightEnabled {
                            Picker("Frequency", selection: $draft.weightFrequency) {
                                Text("Daily").tag(WeightReminderFrequency.daily)
                                Text("Weekly").tag(WeightReminderFrequency.weekly)
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("weight-reminder-frequency")

                            DatePicker(
                                "Time",
                                selection: timeBinding(\.weightTime),
                                displayedComponents: .hourAndMinute
                            )
                            .accessibilityIdentifier("weight-reminder-time")
                        }
                    } header: {
                        Text("Weight")
                    } footer: {
                        Text(draft.weightFrequency == .weekly
                             ? "Weekly waits seven days after your latest weight."
                             : "Daily skips a day as soon as you record a weight.")
                    }
                }

                if showsWater {
                    Section {
                        Toggle("Water", isOn: $draft.waterEnabled)
                            .accessibilityIdentifier("water-reminder-toggle")
                    } header: {
                        Text("Water")
                    } footer: {
                        Text("Every two hours during fixed \(waterReminderStartText)–\(waterReminderEndText) hours when no glass was logged recently; stops at 8 glasses.")
                    }
                }

                if authorizationState == .denied, draft.hasEnabledReminder {
                    Section {
                        Label("Notification access is off", systemImage: "bell.slash")
                    } footer: {
                        Text("Save keeps these choices. Allow notifications from the Reminders screen to start delivery.")
                    }
                }
            }
            .navigationTitle(focus.title)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(focus.editorIdentifier)
            .disabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("reminders-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") {
                        save()
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("reminders-save")
                }
            }
            .alert("Could not complete reminder setup", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .task {
                guard showsMeals else { return }
                await Task.yield()
                proxy.scrollTo("reminder-editor-meals", anchor: .top)
            }
            }
        }
    }

    private var mealsToEdit: [ReminderMeal] {
        ReminderMeal.allCases
    }

    private var showsMeals: Bool {
        focus == .mealAvailability || focus == .mealTimes
    }

    private var showsWeight: Bool {
        focus == .weight
    }

    private var showsWater: Bool {
        focus == .water
    }

    private func enabledBinding(for meal: ReminderMeal) -> Binding<Bool> {
        Binding(
            get: { draft.isEnabled(meal) },
            set: { enabled in
                switch meal {
                case .breakfast: draft.breakfastEnabled = enabled
                case .lunch: draft.lunchEnabled = enabled
                case .snack: draft.snackEnabled = enabled
                case .dinner: draft.dinnerEnabled = enabled
                }
            }
        )
    }

    private func timeBinding(for meal: ReminderMeal) -> Binding<Date> {
        switch meal {
        case .breakfast: timeBinding(\.breakfastTime)
        case .lunch: timeBinding(\.lunchTime)
        case .snack: timeBinding(\.snackTime)
        case .dinner: timeBinding(\.dinnerTime)
        }
    }

    private func timeBinding(
        _ keyPath: WritableKeyPath<ReminderPreferences, ReminderTime>
    ) -> Binding<Date> {
        Binding(
            get: { date(for: draft[keyPath: keyPath]) },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                guard let hour = components.hour, let minute = components.minute else { return }
                draft[keyPath: keyPath] = ReminderTime(hour: hour, minute: minute)
            }
        )
    }

    private func date(for time: ReminderTime) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2001,
            month: 1,
            day: 1,
            hour: time.hour,
            minute: time.minute
        )) ?? .now
    }

    private func save() {
        isSaving = true
        Task { @MainActor in
            if let message = await onSave(draft) {
                errorMessage = message
                isSaving = false
            } else {
                dismiss()
            }
        }
    }
}

private var waterReminderStartText: String {
    timeText(ReminderTime(
        hour: ReminderSchedulePlanner.waterReminderStartHour,
        minute: 0
    ))
}

private var waterReminderEndText: String {
    timeText(ReminderTime(
        hour: ReminderSchedulePlanner.waterReminderEndHour,
        minute: 0
    ))
}

private var waterReminderWindowText: String {
    "\(waterReminderStartText)–\(waterReminderEndText)"
}

private func timeText(_ time: ReminderTime) -> String {
    let calendar = Calendar.current
    let date = calendar.date(from: DateComponents(
        timeZone: calendar.timeZone,
        year: 2001,
        month: 1,
        day: 1,
        hour: time.hour,
        minute: time.minute
    )) ?? .now
    return date.formatted(date: .omitted, time: .shortened)
}

#if DEBUG
#Preview("Reminders") {
    NavigationStack {
        ReminderSettingsView(
            preferences: ReminderPreferences(
                breakfastEnabled: true,
                dinnerEnabled: true,
                waterEnabled: true,
                weightEnabled: true
            ),
            authorizationState: .authorized,
            refreshesAuthorization: false,
            onSaved: { _, _ in }
        )
    }
    .modelContainer(PreviewData.makeContainer())
}

#Preview("Reminder editor") {
    ReminderEditor(
        initialPreferences: ReminderPreferences(
            breakfastEnabled: true,
            dinnerEnabled: true,
            waterEnabled: true,
            weightEnabled: true
        ),
        authorizationState: .authorized,
        onSave: { _ in nil }
    )
}

#Preview("Reminders denied") {
    NavigationStack {
        ReminderSettingsView(
            preferences: ReminderPreferences(
                breakfastEnabled: true,
                dinnerEnabled: true,
                weightEnabled: true
            ),
            authorizationState: .denied,
            refreshesAuthorization: false,
            onSaved: { _, _ in }
        )
    }
    .modelContainer(PreviewData.makeContainer())
}

#Preview("Reminder editor — Small", traits: .fixedLayout(width: 375, height: 667)) {
    ReminderEditor(
        initialPreferences: ReminderPreferences(
            breakfastEnabled: true,
            dinnerEnabled: true,
            waterEnabled: true,
            weightEnabled: true
        ),
        authorizationState: .authorized,
        onSave: { _ in nil }
    )
}
#endif
