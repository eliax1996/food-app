import SwiftData
import SwiftUI
import os

struct CalorieDiaryView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \Food.name) private var foods: [Food]
    @Query(sort: \FoodLogCompletion.attestedAt, order: .reverse) private var completions: [FoodLogCompletion]
    @Query private var profiles: [UserProfile]

    @State private var selectedDate: Date
    @State private var showingAddFood = false
    @State private var deletedSnapshot: PlateEntryMutationSnapshot?
    @State private var errorMessage: String?

    init(initialDate: Date) {
        _selectedDate = State(initialValue: initialDate)
    }

    private var records: [CalorieDiaryRecord] {
        entries.map { entry in
            CalorieDiaryRecord(
                id: entry.stableID,
                date: entry.date,
                mealType: entry.mealType,
                foodName: entry.foodName,
                calories: entry.calories,
                loggedAmount: entry.loggedAmount,
                portionCount: entry.portionQuantity,
                unitRawValue: entry.servingUnitRawValue,
                carbohydratesGrams: entry.carbohydratesGrams,
                proteinGrams: entry.proteinGrams,
                fatGrams: entry.fatGrams,
                fiberGrams: entry.fiberGrams,
                modifiedAt: entry.modifiedAt,
                loggedSnapshotKindRawValue: entry.loggedSnapshotKindRawValue,
                loggedCalorieDensity: entry.resolvedLoggedCalorieDensity
            )
        }
    }

    private var days: [CalorieDiaryDay] {
        CalorieDiary.days(from: records, calendar: calendar)
    }

    private var selectedDay: CalorieDiaryDay? {
        days.first { $0.date == selectedDate }
    }

    private var adjacentDays: (previous: CalorieDiaryDay?, next: CalorieDiaryDay?) {
        CalorieDiary.adjacentDays(to: selectedDate, in: days)
    }

    private var selectedCompletion: FoodLogCompletion? {
        let identity = (String(describing: calendar.identifier), calendar.timeZone.identifier)
        return completions.first {
            $0.calendarIdentifier == identity.0
                && $0.timeZoneIdentifier == identity.1
                && $0.dayStart == selectedDate
        }
    }

    private var historicalGoal: Int? {
        let revisions = profiles.first?.adaptivePlanState?.goalRevisions.map {
            CalorieGoalRevisionPoint(
                effectiveDate: $0.effectiveDay,
                sequence: $0.sequence,
                calories: $0.calories
            )
        } ?? []
        return ProgressHistory.calorieGoal(
            for: selectedDate,
            revisions: revisions,
            calendar: calendar
        )
    }

    private var selectedDayAcceptsNewFood: Bool {
        selectedDate.timeIntervalSinceReferenceDate.isFinite
            && selectedDate <= calendar.startOfDay(for: .now)
    }

    private var mutableFoods: [Food] {
        foods.filter {
            $0.stableID != .zero
                && FoodCaloriePolicy.isValid($0.calories)
                && $0.servingGrams.isFinite
                && $0.servingGrams > 0
        }
    }

    var body: some View {
        List {
            Section {
                dayHeader
            }

            if let deletedSnapshot {
                Section {
                    HStack(alignment: .center, spacing: 12) {
                        Label("Deleted \(deletedSnapshot.foodName)", systemImage: "trash")
                            .font(.subheadline)
                            .lineLimit(2)
                            .accessibilityIdentifier("calorie-diary-delete-undo")
                        Spacer(minLength: 8)
                        Button("Undo", action: undoDeletion)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("calorie-diary-undo-delete")
                    }
                }
            }

            Section {
                Button {
                    showingAddFood = true
                } label: {
                    Label("Log Food on This Day", systemImage: "plus.circle.fill")
                        .frame(minHeight: 44)
                }
                .disabled(mutableFoods.isEmpty || !selectedDayAcceptsNewFood)
                .accessibilityIdentifier("calorie-diary-add-food")

                if !selectedDayAcceptsNewFood {
                    Text("Future-dated legacy days are read-only. Choose today or an earlier date to log food.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if mutableFoods.isEmpty {
                    Text("Create or save a food from Today before logging it on a historical day.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let selectedDay {
                ForEach(selectedDay.mealGroups) { group in
                    Section(group.mealType) {
                        ForEach(group.records) { record in
                            NavigationLink {
                                CalorieDiaryEntryDetailView(
                                    record: record,
                                    completionIsCurrent: selectedCompletion.map {
                                        !$0.isStale
                                            && $0.evidenceSchemaVersion == PlanEvidenceMutationCoordinator.evidenceSchemaVersion
                                    } ?? false,
                                    onMutation: synchronizeAfterMutation,
                                    onDelete: { snapshot in
                                        deletedSnapshot = snapshot
                                        synchronizeAfterMutation()
                                    }
                                )
                            } label: {
                                CalorieDiaryEntryRow(record: record)
                            }
                            .accessibilityIdentifier("calorie-diary-open-entry-\(record.id.uuidString)")
                        }
                        mealTotal(group.calorieTotal)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No recorded foods",
                    systemImage: "fork.knife",
                    description: Text(deletedSnapshot == nil
                        ? "Choose another recorded day from Progress."
                        : "Undo the deletion or log food on this day.")
                )
                .accessibilityIdentifier("calorie-diary-empty")
            }
        }
        .navigationTitle("Food Diary")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("calorie-diary")
        .sheet(isPresented: $showingAddFood) {
            HistoricalFoodAddView(
                foods: mutableFoods,
                initialDate: defaultEntryDate,
                onSaved: { snapshot in
                    selectedDate = calendar.startOfDay(for: snapshot.date)
                    deletedSnapshot = nil
                    synchronizeAfterMutation()
                }
            )
        }
        .alert("Could not update Food Diary", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .task {
            selectedDate = calendar.startOfDay(for: selectedDate)
            let operation = AppLogger.begin(
                "food_diary.refresh_staleness",
                category: .persistence,
                source: "food_diary"
            )
            do {
                mutationCoordinator?.synchronizeCalendar(calendar)
                let count = try mutationCoordinator?.refreshFoodLogStaleness() ?? 0
                AppLogger.succeed(operation, count: count)
            } catch {
                AppLogger.fail(operation, error: error, rollback: "succeeded")
            }
        }
        .onChange(of: days.map(\.date)) { _, availableDates in
            guard !availableDates.contains(selectedDate), deletedSnapshot == nil,
                  let nearest = availableDates.min(by: {
                      abs($0.timeIntervalSinceReferenceDate - selectedDate.timeIntervalSinceReferenceDate)
                          < abs($1.timeIntervalSinceReferenceDate - selectedDate.timeIntervalSinceReferenceDate)
                  }) else { return }
            selectedDate = nearest
        }
    }

    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("calorie-diary-date")

            if let selectedDay {
                if selectedDay.calorieTotal.isComplete {
                    Text("\(selectedDay.calorieTotal.calories.formatted()) kcal")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .accessibilityIdentifier("calorie-diary-total")
                } else {
                    Label("Calorie total incomplete", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("calorie-diary-total-incomplete")
                    Text("Known entries total \(selectedDay.calorieTotal.calories.formatted()) kcal. One or more logged foods has invalid legacy calorie data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(entryCountText(selectedDay.entryCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("calorie-diary-entry-count")
            }

            LabeledContent("Historical goal") {
                Text(historicalGoal.map { "\($0.formatted()) kcal" } ?? "Unavailable")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .accessibilityIdentifier("calorie-diary-historical-goal")

            completionLabel

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    dayNavigationButton(
                        title: "Previous Recorded Day",
                        systemImage: "chevron.left",
                        day: adjacentDays.previous
                    )
                    dayNavigationButton(
                        title: "Next Recorded Day",
                        systemImage: "chevron.right",
                        day: adjacentDays.next
                    )
                }
            } else {
                HStack(spacing: 12) {
                    dayNavigationButton(
                        title: "Previous",
                        systemImage: "chevron.left",
                        day: adjacentDays.previous
                    )
                    dayNavigationButton(
                        title: "Next",
                        systemImage: "chevron.right",
                        day: adjacentDays.next
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var completionLabel: some View {
        if let completion = selectedCompletion {
            if completion.isStale
                || completion.evidenceSchemaVersion != PlanEvidenceMutationCoordinator.evidenceSchemaVersion {
                Label("Food log needs reconfirmation", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("calorie-diary-completion-stale")
            } else {
                Label("Food log complete", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("calorie-diary-completion-complete")
            }
        } else {
            Label("No food-log attestation", systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("calorie-diary-completion-none")
        }
    }

    private var defaultEntryDate: Date {
        if calendar.isDate(selectedDate, inSameDayAs: .now) { return .now }
        let time = calendar.dateComponents([.hour, .minute], from: .now)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }

    private func dayNavigationButton(
        title: String,
        systemImage: String,
        day: CalorieDiaryDay?
    ) -> some View {
        Button {
            guard let day else { return }
            selectedDate = day.date
            deletedSnapshot = nil
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(day == nil)
        .accessibilityValue(day?.date.formatted(date: .complete, time: .omitted) ?? "No recorded day")
        .accessibilityIdentifier(systemImage == "chevron.left"
            ? "calorie-diary-previous-day"
            : "calorie-diary-next-day")
    }

    private func mealTotal(_ total: FoodCalorieTotal) -> some View {
        HStack {
            Text(total.isComplete ? "Meal total" : "Meal total incomplete")
                .foregroundStyle(.secondary)
            Spacer()
            Text(total.isComplete ? "\(total.calories.formatted()) kcal" : "Unavailable")
                .fontWeight(.semibold)
                .foregroundStyle(total.isComplete ? Color.primary : Color.orange)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    private func entryCountText(_ count: Int) -> String {
        count == 1 ? "1 logged food" : "\(count) logged foods"
    }

    private func undoDeletion() {
        guard let deletedSnapshot else { return }
        let operation = AppLogger.begin(
            "food_diary.restore",
            category: .userAction,
            source: "food_diary"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            _ = try mutationCoordinator.restoreHistoricalPlate(deletedSnapshot)
            self.deletedSnapshot = nil
            selectedDate = calendar.startOfDay(for: deletedSnapshot.date)
            synchronizeAfterMutation()
            AppLogger.succeed(operation)
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = "Deleted food could not be restored. Please try again."
        }
    }

    private func synchronizeAfterMutation() {
        TodayExternalSurfaceCoordinator.synchronize(
            modelContext: modelContext,
            calendar: calendar
        )
    }
}

private struct CalorieDiaryEntryDetailView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator

    let record: CalorieDiaryRecord
    let completionIsCurrent: Bool
    let onMutation: () -> Void
    let onDelete: (PlateEntryMutationSnapshot) -> Void

    @State private var presentation: EntryPresentation?
    @State private var confirmingDelete = false
    @State private var copiedSnapshot: PlateEntryMutationSnapshot?
    @State private var errorMessage: String?

    private enum EntryPresentation: String, Identifiable {
        case edit
        case copy
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section("Logged snapshot") {
                LabeledContent("Food", value: record.foodName)
                LabeledContent("Meal", value: mealName)
                LabeledContent("Logged", value: record.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Amount", value: servingText)
                LabeledContent("Calories", value: calorieText)
            }

            if hasAnyNutrient {
                Section("Logged nutrients") {
                    nutrientRow("Carbs", value: record.carbohydratesGrams)
                    nutrientRow("Protein", value: record.proteinGrams)
                    nutrientRow("Fat", value: record.fatGrams)
                    nutrientRow("Fiber", value: record.fiberGrams)
                }
            }

            if !record.canEditOrCopy {
                Section {
                    Label("Legacy entry—item details cannot be verified", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("This row stays visible and can be deleted with undo, but Count Calories will not edit or copy it as an individual food.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("calorie-diary-legacy-entry")
            }

            if let copiedSnapshot {
                Section {
                    HStack(spacing: 12) {
                        Label(
                            "Copied to \(copiedSnapshot.date.formatted(date: .abbreviated, time: .shortened))",
                            systemImage: "checkmark.circle"
                        )
                        .font(.subheadline)
                        .accessibilityIdentifier("calorie-diary-copy-success")
                        Spacer(minLength: 8)
                        Button("Undo Copy", action: undoCopy)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("calorie-diary-undo-copy")
                    }
                }
            }

            Section("Actions") {
                Button {
                    presentation = .edit
                } label: {
                    Label("Edit Logged Food", systemImage: "pencil")
                        .frame(minHeight: 44)
                }
                .disabled(!canEditOrCopy)
                .accessibilityIdentifier("calorie-diary-edit-food")

                Button {
                    presentation = .copy
                } label: {
                    Label("Copy Food", systemImage: "doc.on.doc")
                        .frame(minHeight: 44)
                }
                .disabled(!canEditOrCopy)
                .accessibilityIdentifier("calorie-diary-copy-food")

                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete Entry", systemImage: "trash")
                        .frame(minHeight: 44)
                }
                .disabled(record.id == .zero)
                .accessibilityIdentifier("calorie-diary-delete-food")
            }
        }
        .navigationTitle(record.foodName)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("calorie-diary-entry-detail")
        .sheet(item: $presentation) { presentation in
            switch presentation {
            case .edit:
                HistoricalFoodEditView(record: record) { _ in
                    onMutation()
                }
            case .copy:
                HistoricalFoodCopyView(record: record) { snapshot in
                    copiedSnapshot = snapshot
                    onMutation()
                }
            }
        }
        .alert("Delete \(record.foodName)?", isPresented: $confirmingDelete) {
            Button("Delete Entry", role: .destructive, action: deleteEntry)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteWarning)
        }
        .alert("Could not update Food Diary", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var canEditOrCopy: Bool {
        record.canEditOrCopy && HistoricalFoodMutation.isValidTimestamp(record.date)
    }

    private var mealName: String {
        MealType(rawValue: record.mealType ?? "")?.rawValue ?? "Unknown meal"
    }

    private var servingText: String {
        historicalServingText(record)
    }

    private var calorieText: String {
        FoodCaloriePolicy.isValid(record.calories) ? "\(record.calories.formatted()) kcal" : "Unavailable"
    }

    private var hasAnyNutrient: Bool {
        [record.carbohydratesGrams, record.proteinGrams, record.fatGrams, record.fiberGrams]
            .contains { $0 != nil }
    }

    private var deleteWarning: String {
        let base = "This removes this persisted entry from \(record.date.formatted(date: .complete, time: .omitted)). You can undo immediately from Food Diary."
        return completionIsCurrent
            ? "\(base) This day’s completed food log will need reconfirmation."
            : base
    }

    private func nutrientRow(_ title: String, value: Double?) -> some View {
        LabeledContent(title) {
            Text(value.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) g" } ?? "Unknown")
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }

    private func undoCopy() {
        guard let copiedSnapshot else { return }
        let operation = AppLogger.begin(
            "food_diary.copy_undo",
            category: .userAction,
            source: "food_diary"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            _ = try mutationCoordinator.deleteHistoricalPlate(
                stableID: copiedSnapshot.stableID,
                expectedModifiedAt: copiedSnapshot.modifiedAt
            )
            self.copiedSnapshot = nil
            onMutation()
            AppLogger.succeed(operation)
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = "Copied food could not be removed. Please try again."
        }
    }

    private func deleteEntry() {
        let operation = AppLogger.begin(
            "food_diary.delete",
            category: .userAction,
            source: "food_diary"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            let snapshot = try mutationCoordinator.deleteHistoricalPlate(
                stableID: record.id,
                expectedModifiedAt: record.modifiedAt
            )
            onDelete(snapshot)
            dismiss()
            AppLogger.succeed(operation)
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = "This historical food could not be deleted. Please try again."
        }
    }
}

private enum HistoricalFoodNumericField: Hashable {
    case amount
    case portions
}

private struct HistoricalFoodAddView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator

    let foods: [Food]
    let onSaved: (PlateEntryMutationSnapshot) -> Void

    @State private var selectedFoodID: UUID
    @State private var amount: Double
    @State private var portionCount = 1.0
    @State private var mealType: MealType
    @State private var date: Date
    @State private var confirmingDuplicate = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: HistoricalFoodNumericField?

    init(
        foods: [Food],
        initialDate: Date,
        onSaved: @escaping (PlateEntryMutationSnapshot) -> Void
    ) {
        self.foods = foods
        self.onSaved = onSaved
        let first = foods.first
        _selectedFoodID = State(initialValue: first?.stableID ?? .zero)
        _amount = State(initialValue: first?.servingGrams ?? 100)
        _mealType = State(initialValue: MealType.suggested(at: initialDate))
        _date = State(initialValue: min(initialDate, .now))
    }

    private var selectedFood: Food? {
        foods.first { $0.stableID == selectedFoodID }
    }

    private var calories: Int? {
        guard let selectedFood else { return nil }
        return CalorieCalculator.calculatedCalories(
            caloriesPerServing: selectedFood.calories,
            servingAmount: selectedFood.servingGrams,
            consumedAmount: amount,
            portionCount: portionCount
        )
    }

    private var canSave: Bool {
        selectedFood != nil
            && calories != nil
            && FoodAmountAdjustment.isValid(amount)
            && FoodAmountAdjustment.isValidPortionCount(portionCount)
            && HistoricalFoodMutation.isValidTimestamp(date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Picker("Saved food", selection: $selectedFoodID) {
                        ForEach(foods) { food in
                            Text(food.name).tag(food.stableID)
                        }
                    }
                    .accessibilityIdentifier("historical-add-food-picker")
                }

                HistoricalFoodFields(
                    amount: $amount,
                    portionCount: $portionCount,
                    mealType: $mealType,
                    date: $date,
                    unit: selectedFood?.nutritionUnit ?? .grams,
                    calories: calories,
                    focusedField: $focusedField
                )
            }
            .navigationTitle("Log Historical Food")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("historical-food-add-editor")
            .onChange(of: selectedFoodID) { _, _ in
                amount = selectedFood?.servingGrams ?? 100
                portionCount = 1
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: { save(allowDuplicate: false) })
                        .disabled(!canSave)
                        .accessibilityIdentifier("historical-food-add-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("historical-food-add-keyboard-done")
                }
            }
            .alert("Similar food already logged", isPresented: $confirmingDuplicate) {
                Button("Keep Both") { save(allowDuplicate: true) }
                    .accessibilityIdentifier("historical-food-add-keep-both")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A matching food is already logged in this meal on the selected day.")
            }
            .alert("Could not log food", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
        .interactiveDismissDisabled()
    }

    private func save(allowDuplicate: Bool) {
        let operation = AppLogger.begin(
            "food_diary.add",
            category: .userAction,
            source: "food_diary"
        )
        do {
            guard let mutationCoordinator, let selectedFood else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            let snapshot = try mutationCoordinator.createHistoricalPlate(
                foodStableID: selectedFood.stableID,
                amount: amount,
                portionCount: portionCount,
                mealType: mealType.rawValue,
                date: date,
                allowDuplicate: allowDuplicate
            )
            onSaved(snapshot)
            dismiss()
            AppLogger.succeed(operation)
        } catch PlanEvidenceMutationError.duplicateHistoricalEntry {
            AppLogger.noop(operation, reason: "duplicate_confirmation_required")
            confirmingDuplicate = true
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = historicalMutationErrorMessage(error)
        }
    }
}

struct HistoricalFoodEditView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator

    let record: CalorieDiaryRecord
    let onSaved: (PlateEntryMutationSnapshot) -> Void

    @State private var amount: Double
    @State private var portionCount: Double
    @State private var mealType: MealType
    @State private var date: Date
    @State private var errorMessage: String?
    @FocusState private var focusedField: HistoricalFoodNumericField?

    init(record: CalorieDiaryRecord, onSaved: @escaping (PlateEntryMutationSnapshot) -> Void) {
        self.record = record
        self.onSaved = onSaved
        _amount = State(initialValue: record.loggedAmount)
        _portionCount = State(initialValue: record.portionCount)
        _mealType = State(initialValue: MealType(rawValue: record.mealType ?? "") ?? .snack)
        _date = State(initialValue: min(record.date, .now))
    }

    private var scaled: HistoricalFoodScaleResult? {
        HistoricalFoodMutation.scaledSnapshot(
            originalCalories: record.calories,
            originalAmount: record.loggedAmount,
            originalPortions: record.portionCount,
            newAmount: amount,
            newPortions: portionCount,
            calorieDensity: record.loggedCalorieDensity
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Snapshot") {
                    LabeledContent("Food", value: record.foodName)
                    Text("Amount changes scale this logged calorie and nutrient snapshot. Current saved-food data is not reloaded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HistoricalFoodFields(
                    amount: $amount,
                    portionCount: $portionCount,
                    mealType: $mealType,
                    date: $date,
                    unit: record.unitRawValue == "ml" ? .milliliters : .grams,
                    calories: scaled?.calories,
                    focusedField: $focusedField
                )
            }
            .navigationTitle("Edit Logged Food")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("historical-food-edit-editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(
                            !record.canEditOrCopy
                                || !HistoricalFoodMutation.isValidTimestamp(record.date)
                                || scaled == nil
                                || !HistoricalFoodMutation.isValidTimestamp(date)
                        )
                        .accessibilityIdentifier("historical-food-edit-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("historical-food-edit-keyboard-done")
                }
            }
            .alert("Could not save change", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
        .interactiveDismissDisabled()
    }

    private func save() {
        let operation = AppLogger.begin(
            "food_diary.edit",
            category: .userAction,
            source: "food_diary"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            let snapshot = try mutationCoordinator.updateHistoricalPlate(
                stableID: record.id,
                expectedModifiedAt: record.modifiedAt,
                amount: amount,
                portionCount: portionCount,
                mealType: mealType.rawValue,
                date: date
            )
            onSaved(snapshot)
            dismiss()
            AppLogger.succeed(operation)
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = historicalMutationErrorMessage(error)
        }
    }
}

private struct HistoricalFoodCopyView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator

    let record: CalorieDiaryRecord
    let onCopied: (PlateEntryMutationSnapshot) -> Void

    @State private var mealType: MealType
    @State private var date = Date.now
    @State private var confirmingDuplicate = false
    @State private var errorMessage: String?

    init(record: CalorieDiaryRecord, onCopied: @escaping (PlateEntryMutationSnapshot) -> Void) {
        self.record = record
        self.onCopied = onCopied
        _mealType = State(initialValue: MealType(rawValue: record.mealType ?? "") ?? .snack)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Copy") {
                    LabeledContent("Food", value: record.foodName)
                    LabeledContent("Snapshot", value: "\(record.calories.formatted()) kcal · \(historicalServingText(record))")
                }
                Section("Destination") {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.rawValue).tag(meal)
                        }
                    }
                    DatePicker(
                        "Date and time",
                        selection: $date,
                        in: ...Date.now,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier("historical-food-copy-date")
                }
            }
            .navigationTitle("Copy Logged Food")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("historical-food-copy-editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy", action: { copy(allowDuplicate: false) })
                        .disabled(
                            !record.canEditOrCopy
                                || !HistoricalFoodMutation.isValidTimestamp(record.date)
                                || !HistoricalFoodMutation.isValidTimestamp(date)
                        )
                        .accessibilityIdentifier("historical-food-copy-save")
                }
            }
            .alert("Similar food already logged", isPresented: $confirmingDuplicate) {
                Button("Keep Both") { copy(allowDuplicate: true) }
                    .accessibilityIdentifier("historical-food-copy-keep-both")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A matching food is already logged in this meal on the selected day.")
            }
            .alert("Could not copy food", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
        .interactiveDismissDisabled()
    }

    private func copy(allowDuplicate: Bool) {
        let operation = AppLogger.begin(
            "food_diary.copy",
            category: .userAction,
            source: "food_diary"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            let snapshot = try mutationCoordinator.copyHistoricalPlate(
                stableID: record.id,
                expectedModifiedAt: record.modifiedAt,
                to: date,
                mealType: mealType.rawValue,
                allowDuplicate: allowDuplicate
            )
            onCopied(snapshot)
            dismiss()
            AppLogger.succeed(operation)
        } catch PlanEvidenceMutationError.duplicateHistoricalEntry {
            AppLogger.noop(operation, reason: "duplicate_confirmation_required")
            confirmingDuplicate = true
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = historicalMutationErrorMessage(error)
        }
    }
}

private struct HistoricalFoodFields: View {
    @Binding var amount: Double
    @Binding var portionCount: Double
    @Binding var mealType: MealType
    @Binding var date: Date
    let unit: NutritionUnit
    let calories: Int?
    let focusedField: FocusState<HistoricalFoodNumericField?>.Binding

    private let adjustments: [(title: String, delta: Double, id: String)] = [
        ("−10", -10, "decrease-10"),
        ("−1", -1, "decrease-1"),
        ("+1", 1, "increase-1"),
        ("+10", 10, "increase-10")
    ]

    var body: some View {
        Section("Serving") {
            LabeledContent(unit == .milliliters ? "Volume" : "Amount") {
                HStack {
                    TextField(
                        unit == .milliliters ? "Milliliters" : "Grams",
                        value: $amount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    .focused(focusedField, equals: .amount)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("historical-food-amount")
                    Text(unit.rawValue)
                        .foregroundStyle(.secondary)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { adjustmentButtons }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { adjustmentButtons }
            }

            LabeledContent("Servings") {
                TextField(
                    "Servings",
                    value: $portionCount,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .focused(focusedField, equals: .portions)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("historical-food-portions")
            }

            LabeledContent("Total") {
                Text(calories.map { "\($0.formatted()) kcal" } ?? "Unsupported")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(calories == nil ? .red : .primary)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("historical-food-total")
        }

        Section("When") {
            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases) { meal in
                    Text(meal.rawValue).tag(meal)
                }
            }
            DatePicker(
                "Date and time",
                selection: $date,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            .accessibilityIdentifier("historical-food-date")
        }
    }

    @ViewBuilder
    private var adjustmentButtons: some View {
        ForEach(adjustments, id: \.id) { adjustment in
            let result = FoodAmountAdjustment.result(for: amount, delta: adjustment.delta)
            Button {
                guard let result else { return }
                amount = result
            } label: {
                Text(adjustment.title)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(result == nil)
            .accessibilityLabel("\(adjustment.delta < 0 ? "Decrease" : "Increase") amount by \(abs(adjustment.delta).formatted()) \(unit.rawValue)")
            .accessibilityIdentifier("historical-food-\(adjustment.id)")
        }
    }
}

private struct CalorieDiaryEntryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let record: CalorieDiaryRecord

    private var hasValidCalories: Bool {
        FoodCaloriePolicy.isValid(record.calories)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    entryDescription
                    calorieLabel
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    entryDescription
                    Spacer(minLength: 8)
                    calorieLabel
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.foodName)
        .accessibilityValue(hasValidCalories
            ? "\(historicalServingText(record)), logged at \(record.date.formatted(date: .omitted, time: .shortened)), \(record.calories) calories\(record.isKnownItemSnapshot ? "" : ", legacy entry")"
            : "\(historicalServingText(record)), logged at \(record.date.formatted(date: .omitted, time: .shortened)), calorie value unavailable, legacy entry")
        .accessibilityHint("Opens logged snapshot details and available actions.")
        .accessibilityIdentifier("calorie-diary-entry-\(record.id.uuidString)")
    }

    private var entryDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(record.foodName)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if !record.isKnownItemSnapshot {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
            }
            Text("\(historicalServingText(record)) · \(record.date.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var calorieLabel: some View {
        if hasValidCalories {
            Text("\(record.calories.formatted()) kcal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        } else {
            Label("Unavailable", systemImage: "exclamationmark.triangle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }
}

private func historicalServingText(_ record: CalorieDiaryRecord) -> String {
    guard record.loggedAmount.isFinite, record.loggedAmount > 0 else { return "Amount unavailable" }
    let amount = record.loggedAmount.formatted(.number.precision(.fractionLength(0...2)))
    guard record.portionCount.isFinite, record.portionCount > 0 else {
        return "\(amount) \(record.unitRawValue)"
    }
    let portions = record.portionCount.formatted(.number.precision(.fractionLength(0...2)))
    if abs(record.portionCount - 1) < 0.000_001 {
        return "1× · \(amount) \(record.unitRawValue)"
    }
    return "\(portions)× · \(amount) \(record.unitRawValue) each"
}

private func historicalMutationErrorMessage(_ error: Error) -> String {
    switch error as? PlanEvidenceMutationError {
    case .historicalMutationUnavailable, .compareAndSetFailed:
        "This logged snapshot changed or cannot be safely edited. Close and reopen Food Diary, then try again."
    case .invalidHistoricalMutation, .invalidCalories:
        "Check amount, servings, meal, and nonfuture date. This change is outside supported bounds."
    case .coordinatorUnavailable:
        "Saved data is unavailable. Nothing changed."
    default:
        "Food Diary could not save this change. Nothing was partially updated."
    }
}

#if DEBUG || RELEASE_VALIDATION
#Preview("Historical food diary") {
    let container = PreviewData.makeContainer(state: .normal)
    let entries = try! container.mainContext.fetch(FetchDescriptor<PlateEntry>())
    NavigationStack {
        CalorieDiaryView(
            initialDate: Calendar.current.startOfDay(for: entries.last?.date ?? .now)
        )
    }
    .previewPlanEvidenceContainer(container)
}
#endif
