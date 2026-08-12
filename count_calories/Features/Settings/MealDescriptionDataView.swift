import SwiftUI

struct MealDescriptionDataView: View {
    @State private var learnedChoiceCount = 0
    @State private var hasDraft = false
    @State private var confirmingClearChoices = false
    @State private var confirmingDiscardDraft = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Learned food choices", value: learnedChoiceCount.formatted())
                    .accessibilityIdentifier("learned-food-choice-count")
                LabeledContent("Saved meal draft", value: hasDraft ? "1" : "None")
                    .accessibilityIdentifier("saved-meal-draft-status")
            } header: {
                Text("On-device data")
            } footer: {
                Text("Learned choices are corrections and selected food records reused for exact matching. They do not train a model and are not uploaded.")
            }

            Section {
                Button("Clear Learned Food Choices", role: .destructive) {
                    confirmingClearChoices = true
                }
                .disabled(learnedChoiceCount == 0)
                .accessibilityIdentifier("clear-learned-food-choices")

                Button("Discard Saved Draft", role: .destructive) {
                    confirmingDiscardDraft = true
                }
                .disabled(!hasDraft)
                .accessibilityIdentifier("discard-saved-meal-draft")
            } header: {
                Text("Controls")
            } footer: {
                Text("Clearing these does not delete foods already logged, saved foods, or Open Food Facts search cache.")
            }

            Section("How data moves") {
                Label("Meal descriptions and dictation are processed on device", systemImage: "iphone.and.arrow.forward")
                Label("Microphone audio is not saved", systemImage: "mic.slash")
                Label("Individual food queries may be sent to Open Food Facts", systemImage: "network")
            }
        }
        .navigationTitle("Meal Description & Draft Data")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .alert("Clear learned food choices?", isPresented: $confirmingClearChoices) {
            Button("Clear Choices", role: .destructive) {
                Task { await clearChoices() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Future meal descriptions will stop reusing your prior corrections and selected matches. Logged foods stay unchanged.")
        }
        .alert("Discard saved meal draft?", isPresented: $confirmingDiscardDraft) {
            Button("Discard Draft", role: .destructive) {
                Task { await discardDraft() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unlogged description and review rows in saved draft will be removed. Logged foods stay unchanged.")
        }
        .alert("Could not update data", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "Unknown error")
        }
    }

    private func refresh() async {
        do {
            let learningStore = try await BulkFoodLearningStore.applicationStore()
            let draftStore = try await BulkFoodDraftStore.applicationStore()
            learnedChoiceCount = await learningStore.count()
            hasDraft = await draftStore.hasDraft()
        } catch {
            learnedChoiceCount = 0
            hasDraft = false
            statusMessage = "Meal description data could not be loaded. Please try again."
        }
    }

    private func clearChoices() async {
        do {
            let store = try await BulkFoodLearningStore.applicationStore()
            try await store.clear()
            learnedChoiceCount = 0
        } catch {
            statusMessage = "Learned food choices could not be cleared. Please try again."
        }
    }

    private func discardDraft() async {
        do {
            let store = try await BulkFoodDraftStore.applicationStore()
            let lease = await store.acquireLease()
            try await store.clear(lease: lease)
            hasDraft = false
        } catch {
            statusMessage = "Saved meal draft could not be discarded. Please try again."
        }
    }
}
