import SwiftData
import SwiftUI
import os

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlateEntry.date, order: .reverse) private var entries: [PlateEntry]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]

    @State private var selectedMetric = HistoryMetric.calories
    @State private var currentWeight = 70.0
    @State private var showingWeightPicker = false
    @State private var draftWeightKilograms = 70
    @State private var draftWeightTenths = 0
    @State private var errorMessage: String?

    init() {}

    private var profile: UserProfile? {
        profiles.first
    }

    private var todaysWeight: WeightEntry? {
        weights.first { Calendar.current.isDateInToday($0.date) }
    }

    private var draftWeight: Double {
        Double(draftWeightKilograms) + Double(draftWeightTenths) / 10
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(HistoryMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(selectedMetric.rawValue) {
                    if selectedMetric == .calories {
                        HistogramChart(
                            items: dailyCalories.map {
                                HistogramItem(
                                    label: $0.date.formatted(.dateTime.month(.abbreviated).day()),
                                    value: Double($0.calories)
                                )
                            },
                            unit: "kcal",
                            tint: .orange
                        )
                    } else {
                        HistogramChart(
                            items: weights.prefix(14).reversed().map { entry in
                                HistogramItem(
                                    label: entry.date.formatted(.dateTime.month(.abbreviated).day()),
                                    value: entry.kilograms
                                )
                            },
                            unit: "kg",
                            tint: .blue
                        )
                    }
                }

                Section("Record weight") {
                    Button {
                        prepareWeightPicker()
                        showingWeightPicker = true
                    } label: {
                        HStack {
                            Text("Current weight")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(currentWeight, format: .number.precision(.fractionLength(1))) kg")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                currentWeight = todaysWeight?.kilograms ?? weights.first?.kilograms ?? profile?.currentWeight ?? 70
            }
            .sheet(isPresented: $showingWeightPicker) {
                weightPickerSheet
            }
            .alert("Could not save weight", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var weightPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("\(draftWeight, format: .number.precision(.fractionLength(1))) kg")
                    .font(.title.bold())
                    .contentTransition(.numericText())

                HStack(spacing: 0) {
                    Picker("Kilograms", selection: $draftWeightKilograms) {
                        ForEach(30...250, id: \.self) { kilograms in
                            Text("\(kilograms)").tag(kilograms)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Picker("Tenths", selection: $draftWeightTenths) {
                        ForEach(0...9, id: \.self) { tenth in
                            Text(".\(tenth)").tag(tenth)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("kg")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 180)
            }
            .padding()
            .navigationTitle("Current weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingWeightPicker = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        recordWeight(draftWeight)
                        showingWeightPicker = false
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    private var dailyCalories: [DailyCalorieSummary] {
        CalorieHistory.dailySummaries(
            for: entries.map { CalorieRecord(date: $0.date, calories: $0.calories) }
        )
    }

    private func prepareWeightPicker() {
        let roundedWeight = (currentWeight * 10).rounded() / 10
        draftWeightKilograms = Int(roundedWeight)
        draftWeightTenths = Int((roundedWeight * 10).rounded()) % 10
    }

    private func recordWeight(_ kilograms: Double) {
        currentWeight = kilograms

        if let todaysWeight {
            todaysWeight.kilograms = kilograms
            todaysWeight.date = .now
        } else {
            modelContext.insert(WeightEntry(kilograms: kilograms))
        }

        profile?.currentWeight = kilograms
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistence.error("Failed to save weight: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your weight could not be saved. Please try again."
        }
    }
}

#if DEBUG
#Preview("History") {
    HistoryView()
        .modelContainer(PreviewData.makeContainer())
}
#endif
