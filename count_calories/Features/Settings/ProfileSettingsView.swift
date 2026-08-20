import SwiftData
import SwiftUI
import os

struct ProfileSettingsView: View {
    let profile: UserProfile

    @State private var showingEditor = false

    var body: some View {
        List {
            Section("Profile") {
                LabeledContent("Age", value: profile.age.formatted())
                    .accessibilityIdentifier("profile-age")
                if let stored = profile.storedCalculatedPlan {
                    LabeledContent("Height") {
                        Text(heightText(
                            stored.plan.input.heightCentimeters,
                            system: stored.measurementSystem
                        ))
                        .monospacedDigit()
                    }
                    LabeledContent("Equation input", value: stored.plan.input.equation.title)
                    LabeledContent("Daily routine") {
                        Text("\(stored.plan.input.activityLevel.title) · \(stored.plan.activityFactor.formatted(.number.precision(.fractionLength(2))))×")
                    }
                }
            }

            Section("Plan use") {
                LabeledContent("Goal source", value: planGoalSourceTitle(profile.planGoalSource))
                    .accessibilityIdentifier("profile-plan-source")
                if profile.planGoalSource == .unknown {
                    Text("Source is unknown, so goal check-ins are paused. Review calculated setup from Plan before enabling them.")
                        .foregroundStyle(.secondary)
                } else if profile.storedCalculatedPlan == nil {
                    Text("Age is saved with your manual profile. Calculated setup asks for every additional required input before making an estimate.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("These are the inputs last accepted in calculated setup. Changing age here never recalculates or silently replaces your current goal.")
                        .foregroundStyle(.secondary)
                }
                Text("Review or redo calculated setup from Plan to change equation, height, routine, units, or pace with a new breakdown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Profile and logs stay on this device", systemImage: "lock")
                Text("This screen sends no profile information to a server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("profile-settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditor = true
                }
                .accessibilityIdentifier("profile-edit")
            }
        }
        .sheet(isPresented: $showingEditor) {
            ProfileEditor(profile: profile)
                .interactiveDismissDisabled()
        }
    }
}

private struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
    @Environment(\.calendar) private var calendar

    let profile: UserProfile

    @State private var age: Int
    @State private var errorMessage: String?

    init(profile: UserProfile) {
        self.profile = profile
        _age = State(initialValue: profile.age)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Age: \(age)", value: $age, in: 1...120)
                        .accessibilityIdentifier("profile-age-editor")
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Calculated setup supports ages 19–78. Editing age here never recalculates or changes your current calorie goal.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("profile-editor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("profile-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("profile-save")
                }
            }
            .alert("Could not save profile", isPresented: Binding(
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
        let operation = AppLogger.begin(
            "profile.save",
            category: .userAction,
            source: "settings"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            try mutationCoordinator.changeProfileContext(age: age)
            dismiss()
            AppLogger.succeed(operation)
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = "Profile changes could not be saved. Try again."
        }
    }
}

private func heightText(
    _ centimeters: Double,
    system: PlanMeasurementSystem
) -> String {
    if system == .metric {
        return "\(centimeters.formatted(.number.precision(.fractionLength(0...1)))) cm"
    }
    let totalInches = PlanUnitConversion.inches(fromCentimeters: centimeters)
    let feet = Int(totalInches / 12)
    let inches = totalInches - Double(feet * 12)
    return "\(feet) ft \(inches.formatted(.number.precision(.fractionLength(0...1)))) in"
}

#if DEBUG || RELEASE_VALIDATION
#Preview("Profile") {
    NavigationStack {
        ProfileSettingsView(profile: UserProfile())
    }
    .previewPlanEvidenceContainer(PreviewData.makeContainer())
}
#endif
