import SwiftData
import SwiftUI
import os

struct PlanSettingsView: View {
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]

    let profile: UserProfile

    @State private var showingEditor = false

    private var referencePlan: NutritionReferencePlan? {
        NutritionReferencePlan(calorieGoal: profile.dailyCalorieGoal)
    }

    private var todaysEntries: [PlateEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todaysNutrition: DailyNutritionSummary {
        DailyNutrition.summary(
            records: todaysEntries.map {
                LoggedNutrition(calories: $0.calories, nutrients: $0.nutrients)
            },
            calorieGoal: profile.dailyCalorieGoal
        )
    }

    var body: some View {
        List {
            currentPlanSection
            referenceSection
            measuredSection
                .id("plan-measured-section")
            methodSection
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("plan-settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditor = true
                }
                .accessibilityIdentifier("plan-edit")
            }
        }
        .sheet(isPresented: $showingEditor) {
            PlanEditor(profile: profile)
                .interactiveDismissDisabled()
        }
    }

    private var currentPlanSection: some View {
        Section {
            LabeledContent("Daily goal") {
                Text("\(profile.dailyCalorieGoal.formatted()) kcal")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            .accessibilityIdentifier("plan-current-calorie-goal")

            LabeledContent("Source") {
                Text("Manual")
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Target weight") {
                Text(weightText(profile.targetWeight))
                    .monospacedDigit()
            }

            LabeledContent("Target date") {
                Text(profile.targetDate.formatted(date: .abbreviated, time: .omitted))
            }
        } header: {
            Text("Current plan")
        } footer: {
            Text("This calorie goal remains manual. Target date is saved for context and has not been checked for feasibility.")
        }
    }

    @ViewBuilder
    private var referenceSection: some View {
        Section {
            if let referencePlan {
                ForEach(Macronutrient.allCases, id: \.self) { nutrient in
                    let reference = referencePlan.reference(for: nutrient)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nutrient.rawValue)
                            .font(.body.weight(.medium))
                        Text("\(rangeText(reference.energyFractionRange)) of energy · \(gramsRangeText(reference.gramsRange))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("plan-reference-\(nutrient.rawValue.lowercased())")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fiber")
                        .font(.body.weight(.medium))
                    Text("14 g per \(1_000.formatted()) kcal · \(gramsText(referencePlan.fiberGrams))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("plan-reference-fiber")
            } else {
                Text("Enter a positive calorie goal to calculate general adult reference ranges.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Reference composition")
        } footer: {
            Text("General adult population ranges—not personal macro targets or medical advice.")
        }
    }

    @ViewBuilder
    private var measuredSection: some View {
        Section {
            if todaysNutrition.hasEntries, let referencePlan {
                ForEach(Macronutrient.allCases, id: \.self) { nutrient in
                    measuredMacroRow(nutrient, reference: referencePlan.reference(for: nutrient))
                }
                measuredFiberRow(reference: referencePlan.fiberGrams)
                Text(coverageText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("plan-nutrition-coverage")
            } else {
                Text("Log food with nutrient details to compare today’s measured intake with these references.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("plan-nutrition-empty")
            }
        } header: {
            Text("Today compared with reference")
        } footer: {
            if todaysNutrition.hasEntries {
                Text("Missing nutrient values stay unknown. Comparisons pause until every logged food has the relevant data.")
            }
        }
    }

    private func measuredMacroRow(
        _ nutrient: Macronutrient,
        reference: MacronutrientReference
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nutrient.rawValue)
                .font(.body.weight(.medium))
            Text(measuredMacroText(nutrient))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text("Reference \(gramsRangeText(reference.gramsRange)) · \(rangeText(reference.energyFractionRange))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan-measured-\(nutrient.rawValue.lowercased())")
    }

    private func measuredFiberRow(reference: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fiber")
                .font(.body.weight(.medium))
            Text(measuredFiberText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text("Reference \(gramsText(reference))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("plan-measured-fiber")
    }

    private var methodSection: some View {
        Section("Basis and scope") {
            Text("Carbohydrate and protein grams use 4 kcal/g; fat uses 9 kcal/g. Measured percent comparisons divide that estimated energy by logged food-label calories, which remain authoritative for your calorie budget.")
            Text("References apply to general adults. Children, pregnancy or lactation, clinical diets, and individual treatment need professional guidance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Link(
                "Dietary Reference Intakes",
                destination: URL(string: "https://doi.org/10.17226/10490")!
            )
        }
    }

    private func measuredMacroText(_ nutrient: Macronutrient) -> String {
        let grams = gramsText(todaysNutrition.knownNutrients.grams(for: nutrient))
        if todaysNutrition.hasCompleteMacroCoverage {
            if let share = todaysNutrition.macroEnergyShare {
                return "Measured \(grams) · \(percentText(share.fraction(for: nutrient))) of logged energy"
            }
            return "Measured \(grams) · logged-energy comparison unavailable"
        }
        return "Known \(grams) · \(todaysNutrition.knownCount(for: nutrient)) of \(todaysNutrition.entryCount) foods; comparison paused"
    }

    private var measuredFiberText: String {
        let grams = gramsText(todaysNutrition.knownNutrients.fiberGrams)
        if todaysNutrition.hasCompleteFiberCoverage {
            return "Measured \(grams)"
        }
        return "Known \(grams) · \(todaysNutrition.fiberKnownCount) of \(todaysNutrition.entryCount) foods; comparison paused"
    }

    private var coverageText: String {
        if todaysNutrition.hasCompleteCoverage {
            return "Complete data for all \(todaysNutrition.entryCount) logged foods"
        }
        return "Macros \(todaysNutrition.macroCompleteCount)/\(todaysNutrition.entryCount) foods · Fiber \(todaysNutrition.fiberKnownCount)/\(todaysNutrition.entryCount)"
    }
}

private struct PlanEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @FocusState private var targetWeightFieldIsFocused: Bool
    @State private var dailyGoal: Int
    @State private var targetWeight: Double
    @State private var targetDate: Date
    @State private var errorMessage: String?

    init(profile: UserProfile) {
        self.profile = profile
        _dailyGoal = State(initialValue: profile.dailyCalorieGoal)
        _targetWeight = State(initialValue: profile.targetWeight)
        _targetDate = State(initialValue: profile.targetDate)
    }

    private var referencePlan: NutritionReferencePlan? {
        NutritionReferencePlan(calorieGoal: dailyGoal)
    }

    private var isValid: Bool {
        (1_000...5_000).contains(dailyGoal)
            && targetWeight.isFinite
            && (20...500).contains(targetWeight)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(
                        "Daily goal: \(dailyGoal.formatted()) kcal",
                        value: $dailyGoal,
                        in: 800...5_000,
                        step: 50
                    )
                    .accessibilityIdentifier("plan-daily-goal")

                    if dailyGoal < 1_000 {
                        Label(
                            "Choose at least 1,000 kcal before saving. Lower adult goals need professional guidance.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Manual calorie goal")
                } footer: {
                    Text("Editing this value does not change logged food or create a calculated recommendation.")
                }

                Section("Weight context") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target weight")
                        HStack {
                            TextField(
                                "Target weight",
                                value: $targetWeight,
                                format: .number.precision(.fractionLength(1))
                            )
                            .keyboardType(.decimalPad)
                            .focused($targetWeightFieldIsFocused)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("plan-target-weight")
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                    DatePicker(
                        "Target date (unverified)",
                        selection: $targetDate,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("plan-target-date")
                }

                Section {
                    if let referencePlan {
                        ForEach(Macronutrient.allCases, id: \.self) { nutrient in
                            let reference = referencePlan.reference(for: nutrient)
                            LabeledContent(nutrient.rawValue) {
                                Text(gramsRangeText(reference.gramsRange))
                                    .monospacedDigit()
                            }
                        }
                        LabeledContent("Fiber") {
                            Text(gramsText(referencePlan.fiberGrams))
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Reference preview")
                } footer: {
                    Text("References recalculate with the draft goal. Save updates the current manual goal.")
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("plan-editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("plan-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                        .accessibilityIdentifier("plan-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        targetWeightFieldIsFocused = false
                    }
                    .accessibilityIdentifier("plan-keyboard-done")
                }
            }
            .alert("Could not save plan", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Dismiss", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func save() {
        guard isValid else { return }

        profile.dailyCalorieGoal = dailyGoal
        profile.targetWeight = targetWeight
        profile.targetDate = targetDate

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error(
                "Failed to save plan settings: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = "Plan changes could not be saved. Try again."
        }
    }
}

private func weightText(_ kilograms: Double) -> String {
    guard kilograms.isFinite, kilograms > 0 else { return "Not set" }
    return "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
}

private func gramsText(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "Not available" }
    return "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
}

private func gramsRangeText(_ range: ClosedRange<Double>) -> String {
    "\(range.lowerBound.formatted(.number.precision(.fractionLength(0...1))))–\(range.upperBound.formatted(.number.precision(.fractionLength(0...1)))) g"
}

private func percentText(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}

private func rangeText(_ range: ClosedRange<Double>) -> String {
    "\(percentText(range.lowerBound))–\(percentText(range.upperBound))"
}

#if DEBUG
#Preview("Plan complete") {
    NavigationStack {
        PlanSettingsView(profile: UserProfile())
    }
    .modelContainer(PreviewData.makeContainer())
}

#Preview("Plan partial") {
    ScrollViewReader { proxy in
        NavigationStack {
            PlanSettingsView(profile: UserProfile())
        }
        .modelContainer(PreviewData.makeContainer(state: .nutritionPartial))
        .task {
            await Task.yield()
            proxy.scrollTo("plan-measured-section", anchor: .top)
        }
    }
}

#Preview("Plan editor") {
    PlanEditor(profile: UserProfile())
        .modelContainer(PreviewData.makeContainer())
}
#endif
