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
            }

            Section("Plan use") {
                Text("Age is saved with your profile. Count Calories does not yet use it to calculate or replace your manual calorie goal.")
                    .foregroundStyle(.secondary)
                Text("Calculated setup will ask for every required input and explain why it is needed before making a recommendation.")
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
                    Text("Automated calorie recommendations are not available for people under 18. Editing age does not change your current manual goal.")
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
        profile.age = age
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            AppLogger.persistence.error(
                "Failed to save profile settings: \(error.localizedDescription, privacy: .public)"
            )
            errorMessage = "Profile changes could not be saved. Try again."
        }
    }
}

#if DEBUG
#Preview("Profile") {
    NavigationStack {
        ProfileSettingsView(profile: UserProfile())
    }
    .modelContainer(PreviewData.makeContainer())
}
#endif
