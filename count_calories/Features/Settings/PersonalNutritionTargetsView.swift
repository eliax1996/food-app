import SwiftData
import SwiftUI
import os

struct PersonalNutritionTargetsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator

    let profile: UserProfile

    @State private var carbohydratesText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var fiberText: String
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case carbohydrates
        case protein
        case fat
        case fiber
    }

    init(profile: UserProfile) {
        self.profile = profile
        let targets = profile.personalNutritionTargets
        _carbohydratesText = State(initialValue: Self.initialText(targets?.carbohydratesGrams))
        _proteinText = State(initialValue: Self.initialText(targets?.proteinGrams))
        _fatText = State(initialValue: Self.initialText(targets?.fatGrams))
        _fiberText = State(initialValue: Self.initialText(targets?.fiberGrams))
    }

    private var parsedValues: (carbohydrates: Double, protein: Double, fat: Double, fiber: Double)? {
        guard let carbohydrates = parsed(carbohydratesText),
              let protein = parsed(proteinText),
              let fat = parsed(fatText),
              let fiber = parsed(fiberText) else {
            return nil
        }
        return (carbohydrates, protein, fat, fiber)
    }

    private var targets: PersonalNutritionTargets? {
        guard let values = parsedValues else { return nil }
        return PersonalNutritionTargets(
            carbohydratesGrams: values.carbohydrates,
            proteinGrams: values.protein,
            fatGrams: values.fat,
            fiberGrams: values.fiber
        )
    }

    private var rawMacroEnergy: Double? {
        guard let values = parsedValues else { return nil }
        let energy = values.carbohydrates * 4 + values.protein * 4 + values.fat * 9
        return energy.isFinite ? energy : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    targetField(
                        "Carbohydrates",
                        text: $carbohydratesText,
                        focus: .carbohydrates,
                        identifier: "personal-target-carbohydrates"
                    )
                    targetField(
                        "Protein",
                        text: $proteinText,
                        focus: .protein,
                        identifier: "personal-target-protein"
                    )
                    targetField(
                        "Fat",
                        text: $fatText,
                        focus: .fat,
                        identifier: "personal-target-fat"
                    )
                    targetField(
                        "Fiber",
                        text: $fiberText,
                        focus: .fiber,
                        identifier: "personal-target-fiber"
                    )
                } header: {
                    Text("Daily gram targets")
                } footer: {
                    Text("Enter all four values. Fields start blank because Count Calories does not turn population references into a personal prescription.")
                }

                Section("Calculated context") {
                    LabeledContent("Macro energy") {
                        Text(rawMacroEnergy.map {
                            "\($0.formatted(.number.precision(.fractionLength(0)))) kcal"
                        } ?? "Enter all macro targets")
                        .monospacedDigit()
                    }
                    .accessibilityIdentifier("personal-target-macro-energy")

                    LabeledContent("Calorie goal") {
                        Text("\(profile.dailyCalorieGoal.formatted()) kcal")
                            .monospacedDigit()
                    }
                }

                if parsedValues != nil, targets == nil {
                    Section {
                        Label("Targets are outside supported bounds", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Use positive finite grams, no more than 200 g fiber, and at most 5,000 kcal from carbohydrate, protein, and fat combined.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("personal-target-validation")
                }

                Section("Meaning") {
                    Text("Targets are values you entered, not recommendations. General adult references remain available in Plan.")
                    Text("Food-label calories remain authoritative for your calorie budget, so macro energy may not match the calorie goal or logged food calories.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nutrition Targets")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("personal-nutrition-targets-editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                        .accessibilityIdentifier("personal-target-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(targets == nil)
                        .accessibilityIdentifier("personal-target-save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .accessibilityIdentifier("personal-target-keyboard-done")
                }
            }
            .alert("Could not save targets", isPresented: Binding(
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

    private func targetField(
        _ title: String,
        text: Binding<String>,
        focus: Field,
        identifier: String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("Required", text: text)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: focus)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)
                    .accessibilityLabel("\(title) target in grams")
                    .accessibilityIdentifier(identifier)
                Text("g")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func parsed(_ text: String) -> Double? {
        PersonalNutritionTargetInput.value(from: text, locale: locale)
    }

    private func save() {
        guard let targets else { return }
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            try mutationCoordinator.setPersonalNutritionTargets(targets)
            dismiss()
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error(
                "Failed to save personal nutrition targets: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = "Personal nutrition targets could not be saved. Nothing changed."
        }
    }

    private static func initialText(_ value: Double?) -> String {
        PersonalNutritionTargetInput.text(for: value)
    }
}

#if DEBUG
#Preview("Personal targets") {
    PersonalNutritionTargetsEditor(profile: UserProfile())
        .previewPlanEvidenceContainer(PreviewData.makeContainer())
}
#endif
