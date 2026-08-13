import SwiftUI

struct NutritionBalanceRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: DailyNutritionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 10 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Nutrition balance", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if summary.hasEntries && !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                    Text(summary.hasCompleteCoverage ? "\(summary.entryCount)/\(summary.entryCount) foods" : "Partial data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if summary.hasEntries {
                if dynamicTypeSize.isAccessibilitySize {
                    if let split = summary.macroSplit {
                        Text("Macro-only energy split")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MacroSplitBar(split: split)
                    }
                    accessibilityMetrics
                    Text(coverageText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(guidanceHeadline)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                } else {
                    if let split = summary.macroSplit {
                        MacroSplitBar(split: split)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        metric(for: .carbohydrates)
                        metric(for: .protein)
                        metric(for: .fat)
                        fiberMetric
                    }
                    Text(summary.hasCompleteCoverage ? compactGuidanceHeadline : coverageText)
                        .font(.footnote.weight(summary.hasCompleteCoverage ? .medium : .regular))
                        .foregroundStyle(summary.hasCompleteCoverage ? Color.primary : Color.secondary)
                        .lineLimit(2)
                }
            } else {
                Text("Log food with nutrient details to see today’s macro and fiber balance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nutrition balance")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityMetrics: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                metric(for: .carbohydrates)
                metric(for: .protein)
            }
            GridRow {
                metric(for: .fat)
                fiberMetric
            }
        }
    }

    private func metric(for nutrient: Macronutrient) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(nutrient.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(metricValue(for: nutrient))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fiberMetric: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Fiber")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(gramsText(summary.knownNutrients.fiberGrams))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricValue(for nutrient: Macronutrient) -> String {
        gramsText(summary.knownNutrients.grams(for: nutrient))
    }

    private var coverageText: String {
        if summary.hasCompleteCoverage {
            return "Complete data for all \(summary.entryCount) logged foods"
        }
        return "Macros \(summary.macroCompleteCount)/\(summary.entryCount) foods · Fiber \(summary.fiberKnownCount)/\(summary.entryCount)"
    }

    private var compactGuidanceHeadline: String {
        "Macro-only split · \(guidanceHeadline)"
    }

    private var guidanceHeadline: String {
        guard summary.hasCompleteCalorieCoverage else {
            return "Guidance paused because logged calorie data is unavailable."
        }
        guard summary.hasCompleteMacroCoverage, let first = summary.guidance.first else {
            return "Guidance paused until macro coverage is complete."
        }
        if first.status == .withinReferences {
            return "Logged-energy shares are inside general adult ranges."
        }
        guard let nutrient = first.nutrient else { return "Measured balance available." }
        switch first.status {
        case .belowReference:
            return "\(nutrient.rawValue) logged-energy share is below the adult range."
        case .aboveReference:
            return "\(nutrient.rawValue) logged-energy share is above the adult range."
        case .withinReferences:
            return "Measured split is within adult reference ranges."
        }
    }

    private var accessibilityValue: String {
        guard summary.hasEntries else {
            return "No logged nutrient data today"
        }
        var values = Macronutrient.allCases.map {
            "\($0.rawValue) \(metricValue(for: $0))"
        } + ["Fiber \(gramsText(summary.knownNutrients.fiberGrams))"]
        if let split = summary.macroSplit {
            values.append(
                "Macro-only energy split: carbs \(percentText(split.carbohydrates)), protein \(percentText(split.protein)), fat \(percentText(split.fat))"
            )
        }
        return (values + [coverageText, guidanceHeadline]).joined(separator: ", ")
    }
}

struct DailyNutritionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: DailyNutritionSummary

    var body: some View {
        List {
            if summary.hasEntries {
                macroSection
                fiberSection
                guidanceSection
                coverageSection
                methodSection
            } else {
                ContentUnavailableView(
                    "No nutrition data today",
                    systemImage: "chart.bar",
                    description: Text("Log food to see measured carbohydrates, protein, fat, and fiber.")
                )
            }
        }
        .navigationTitle("Nutrition balance")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("daily-nutrition-detail")
    }

    private var macroSection: some View {
        Section("Macronutrients") {
            if let split = summary.macroSplit {
                if !dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macro-only energy split")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MacroSplitBar(split: split)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Macro percentages appear only when every logged food has carbohydrate, protein, and fat data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(Macronutrient.allCases, id: \.self) { nutrient in
                macroRow(nutrient)
            }
        }
    }

    @ViewBuilder
    private func macroRow(_ nutrient: Macronutrient) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text(nutrient.rawValue)
                Text(gramsText(summary.knownNutrients.grams(for: nutrient)))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                macroDetail(for: nutrient)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("nutrition-macro-\(nutrient.rawValue.lowercased())")
        } else {
            LabeledContent(nutrient.rawValue) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(gramsText(summary.knownNutrients.grams(for: nutrient)))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    macroDetail(for: nutrient)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("nutrition-macro-\(nutrient.rawValue.lowercased())")
        }
    }

    private func macroDetail(for nutrient: Macronutrient) -> Text {
        if let share = summary.macroEnergyShare {
            Text("\(percentText(share.fraction(for: nutrient))) of logged energy · adult range \(rangeText(nutrient.referenceRange))")
        } else if summary.hasCompleteMacroCoverage {
            Text("Logged-energy comparison unavailable")
        } else {
            Text("\(summary.knownCount(for: nutrient)) of \(summary.entryCount) foods")
        }
    }

    private var fiberSection: some View {
        Section("Fiber") {
            LabeledContent("Measured") {
                Text(gramsText(summary.knownNutrients.fiberGrams))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            .accessibilityIdentifier("nutrition-fiber-measured")

            if summary.hasCompleteFiberCoverage,
               let fiber = summary.knownNutrients.fiberGrams,
               let reference = summary.fiberReferenceGrams {
                ProgressView(value: min(fiber / max(reference, 0.01), 1))
                    .tint(.blue)
                    .accessibilityLabel("Fiber compared with adult reference")
                    .accessibilityValue("\(gramsText(fiber)) of \(gramsText(reference))")
                HStack {
                    Text("0 g")
                    Spacer()
                    Text("\(gramsText(reference)) reference")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Energy-scaled adult reference for this calorie goal.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Fiber reference comparison is paused. Data is available for \(summary.fiberKnownCount) of \(summary.entryCount) foods.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var guidanceSection: some View {
        Section("Measured guidance") {
            if summary.hasCompleteMacroCoverage, summary.macroEnergyShare != nil {
                ForEach(Array(summary.guidance.enumerated()), id: \.offset) { index, guidance in
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(guidanceTitle(guidance))
                                .font(.headline)
                            Text(guidanceMessage(guidance))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: guidance.status == .withinReferences ? "info.circle" : "lightbulb")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("nutrition-guidance-\(index)")
                }
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Guidance paused")
                            .font(.headline)
                        Text(guidancePausedReason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "pause.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("nutrition-guidance")
    }

    private var guidancePausedReason: String {
        if !summary.hasCompleteCalorieCoverage {
            return "Food-label calories are valid for \(summary.calorieValidCount) of \(summary.entryCount) logged foods. Logged-energy guidance is unavailable; no missing values were estimated."
        }
        return "Macro data is complete for \(summary.macroCompleteCount) of \(summary.entryCount) logged foods. No missing values were estimated."
    }

    private var coverageSection: some View {
        Section("Data coverage") {
            LabeledContent("Macros", value: "\(summary.macroCompleteCount) of \(summary.entryCount) foods")
                .accessibilityIdentifier("nutrition-macro-coverage")
            LabeledContent("Fiber", value: "\(summary.fiberKnownCount) of \(summary.entryCount) foods")
                .accessibilityIdentifier("nutrition-fiber-coverage")
            LabeledContent("All four", value: "\(summary.completeCount) of \(summary.entryCount) foods")
                .accessibilityIdentifier("nutrition-complete-coverage")
            Text("Unknown values stay blank and do not count as zero. Open Food Facts is crowdsourced, so complete fields can still be inaccurate or outdated.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var methodSection: some View {
        Section("How this works") {
            Text("The colored split normalizes measured carbohydrate and protein at 4 kcal/g and fat at 9 kcal/g. Adult-range comparisons divide each macro’s estimated energy by logged food-label calories, so rounding and other energy sources can keep the shares from totaling 100%.")
            Text("Adult population reference ranges: carbs 45–65%, protein 10–35%, and fat 20–35%. Fiber uses 14 g per 1,000 kcal.")
            Text("General information only—not medical advice or a personal prescription.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Link(
                "Dietary Reference Intakes",
                destination: URL(string: "https://doi.org/10.17226/10490")!
            )
            Link(
                "FDA calorie factors",
                destination: URL(string: "https://www.ecfr.gov/current/title-21/chapter-I/subchapter-B/part-101/subpart-A/section-101.9")!
            )
        }
    }

    private func guidanceTitle(_ guidance: MacroGuidance) -> String {
        if guidance.status == .withinReferences {
            return "General adult range comparison"
        }
        guard let nutrient = guidance.nutrient else { return "Measured balance" }
        return guidance.status == .belowReference
            ? "\(nutrient.rawValue) below range"
            : "\(nutrient.rawValue) above range"
    }

    private func guidanceMessage(_ guidance: MacroGuidance) -> String {
        guard
            let nutrient = guidance.nutrient,
            let measured = guidance.measuredFraction,
            let range = guidance.referenceRange
        else {
            return "All measured macro shares fall inside adult population reference ranges. These ranges are general information, not personal targets."
        }

        let measurement = "\(nutrient.rawValue) provides about \(percentText(measured)) of logged food-label energy; adult reference is \(rangeText(range))."
        let action: String
        switch (nutrient, guidance.status) {
        case (.protein, .belowReference):
            action = "Consider a protein-rich option if it fits your needs."
        case (.fat, .aboveReference):
            action = "A lower-fat option could move the split closer to the range."
        case (.carbohydrates, .belowReference):
            action = "A carbohydrate-containing option could move the split closer to the range."
        default:
            action = "Reviewing food and portion choices could move the split closer to the range."
        }
        return "\(measurement) \(action)"
    }
}

private struct MacroSplitBar: View {
    let split: MacroEnergySplit

    var body: some View {
        Canvas { context, size in
            guard size.width.isFinite, size.height.isFinite, size.width > 4, size.height > 0 else {
                return
            }
            let availableWidth = size.width - 4
            let segments: [(Double, Color)] = [
                (split.carbohydrates, .blue),
                (split.protein, .orange),
                (split.fat, .purple)
            ]
            var originX = 0.0
            for (fraction, color) in segments {
                let width = availableWidth * fraction
                context.fill(
                    Path(CGRect(x: originX, y: 0, width: width, height: size.height)),
                    with: .color(color)
                )
                originX += width + 2
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Normalized measured macro energy split")
        .accessibilityValue(
            "Carbs \(percentText(split.carbohydrates)), protein \(percentText(split.protein)), fat \(percentText(split.fat))"
        )
    }
}

private func gramsText(_ value: Double?) -> String {
    guard let value else { return "Not available" }
    return "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
}

private func percentText(_ value: Double) -> String {
    value.formatted(.percent.precision(.fractionLength(0)))
}

private func rangeText(_ range: ClosedRange<Double>) -> String {
    "\(percentText(range.lowerBound))–\(percentText(range.upperBound))"
}

#if DEBUG
private struct PushedNutritionPreview<Destination: View>: View {
    @State private var path = [1]

    let rootTitle: String
    let destination: Destination

    init(rootTitle: String, @ViewBuilder destination: () -> Destination) {
        self.rootTitle = rootTitle
        self.destination = destination()
    }

    var body: some View {
        NavigationStack(path: $path) {
            Color.clear
                .navigationTitle(rootTitle)
                .navigationDestination(for: Int.self) { _ in
                    destination
                }
        }
        .environment(\.locale, Locale(identifier: "en_US"))
    }
}

private let completeNutritionPreview = DailyNutrition.summary(
    records: [
        LoggedNutrition(
            calories: 360,
            nutrients: FoodNutrients(
                carbohydratesGrams: 62,
                proteinGrams: 12,
                fatGrams: 7,
                fiberGrams: 9
            )
        ),
        LoggedNutrition(
            calories: 540,
            nutrients: FoodNutrients(
                carbohydratesGrams: 55,
                proteinGrams: 48,
                fatGrams: 17,
                fiberGrams: 10
            )
        ),
        LoggedNutrition(
            calories: 180,
            nutrients: FoodNutrients(
                carbohydratesGrams: 25,
                proteinGrams: 20,
                fatGrams: 5,
                fiberGrams: 0
            )
        )
    ],
    calorieGoal: 1_700
)

#Preview("Nutrition balance row") {
    NavigationStack {
        List {
            NutritionBalanceRow(summary: completeNutritionPreview)
        }
    }
}

#Preview("Nutrition detail") {
    PushedNutritionPreview(rootTitle: "Today") {
        DailyNutritionView(summary: completeNutritionPreview)
    }
}

#Preview("Nutrition measured guidance") {
    PushedNutritionPreview(rootTitle: "Today") {
        DailyNutritionView(summary: DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 1_080,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 100,
                        proteinGrams: 10,
                        fatGrams: 50,
                        fiberGrams: 8
                    )
                )
            ],
            calorieGoal: 1_700
        ))
    }
}

#Preview("Nutrition partial coverage") {
    PushedNutritionPreview(rootTitle: "Today") {
        DailyNutritionView(summary: DailyNutrition.summary(
            records: [
                LoggedNutrition(
                    calories: 360,
                    nutrients: FoodNutrients(
                        carbohydratesGrams: 62,
                        proteinGrams: 12,
                        fatGrams: 7,
                        fiberGrams: 9
                    )
                ),
                LoggedNutrition(
                    calories: 180,
                    nutrients: FoodNutrients(
                        proteinGrams: 20,
                        fatGrams: 5
                    )
                )
            ],
            calorieGoal: 1_700
        ))
    }
}
#endif
