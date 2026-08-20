import SwiftData
import SwiftUI
import os

struct CaloriePlanSetupView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator

    let profile: UserProfile?
    let onFinish: () -> Void

    private let acceptedPlanDateAtStart: Date?

    @State private var draft: CaloriePlanSetupDraft
    @State private var errorMessage: String?
    @FocusState private var focusedField: NumericField?

    private enum NumericField: Hashable {
        case currentWeight
        case targetWeight
        case heightCentimeters
        case heightFeet
        case heightInches
    }

    init(
        profile: UserProfile?,
        record: CaloriePlanSetupRecord,
        onFinish: @escaping () -> Void
    ) {
        self.profile = profile
        self.onFinish = onFinish
        acceptedPlanDateAtStart = record.acceptedPlanDateAtStart
        _draft = State(initialValue: record.draft)
    }

    var body: some View {
        NavigationStack {
            page
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if draft.step != .welcome {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back", action: goBack)
                                .accessibilityIdentifier("calculated-setup-back")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close", action: closeAndResumeLater)
                            .accessibilityIdentifier("calculated-setup-close")
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                        .accessibilityIdentifier("calculated-setup-keyboard-done")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    actionBar
                }
        }
        .interactiveDismissDisabled()
        .accessibilityIdentifier("calculated-plan-setup")
        .onChange(of: draft) { _, newDraft in
            guard newDraft.step != .welcome || newDraft.eligibilityConfirmed else { return }
            persist(status: .inProgress)
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

    @ViewBuilder
    private var page: some View {
        switch draft.step {
        case .welcome:
            welcomePage
        case .goal:
            goalPage
        case .body:
            bodyPage
        case .equation:
            equationPage
        case .activity:
            activityPage
        case .pace:
            pacePage
        case .review:
            reviewPage
        }
    }

    private var welcomePage: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "target")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text("Build an explainable starting plan")
                        .font(.title2.weight(.semibold))
                    Text("You can inspect every input and keep your current manual goal instead. Nothing changes until you confirm the review.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Label("For adults ages 19–78", systemImage: "person")
                Label("Not for pregnancy or breastfeeding", systemImage: "cross.case")
                Label("Not for clinician-directed nutrition care", systemImage: "stethoscope")
                Label("Estimate only—not medical advice", systemImage: "info.circle")
            } header: {
                Text("Scope")
            } footer: {
                Text("A manual goal remains available when this scope does not fit.")
            }

            Section {
                Toggle(
                    "This scope fits me",
                    isOn: $draft.eligibilityConfirmed
                )
                .accessibilityIdentifier("calculated-setup-eligibility")
            }
        }
    }

    private var goalPage: some View {
        Form {
            progressSection
            Section {
                ForEach(PlanGoalMode.allCases, id: \.self) { mode in
                    selectionRow(
                        title: mode.title,
                        detail: goalDetail(mode),
                        selected: draft.goalMode == mode,
                        identifier: "calculated-goal-\(mode.rawValue)"
                    ) {
                        selectGoalMode(mode)
                    }
                }
            } header: {
                Text("What should this starting plan support?")
            } footer: {
                Text("Goal mode changes the estimate only after final confirmation.")
            }
        }
    }

    private var bodyPage: some View {
        Form {
            progressSection

            Section {
                Text("The resting-energy equation requires age, height, and current weight. Values stay on this device and do not change your plan until review confirmation.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Why these details are needed")
            }

            Section {
                Picker("Units", selection: $draft.measurementSystem) {
                    ForEach(PlanMeasurementSystem.allCases, id: \.self) { system in
                        Text(system.title).tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("calculated-setup-units")
            } footer: {
                Text("Values are stored in metric units on this device. Switching units does not change them.")
            }

            Section("Weight") {
                measurementField(
                    title: "Current weight",
                    value: currentWeightBinding,
                    unit: draft.measurementSystem == .metric ? "kg" : "lb",
                    focus: .currentWeight,
                    identifier: "calculated-current-weight"
                )

                if draft.goalMode != .maintain {
                    measurementField(
                        title: "Target weight",
                        value: targetWeightBinding,
                        unit: draft.measurementSystem == .metric ? "kg" : "lb",
                        focus: .targetWeight,
                        identifier: "calculated-target-weight"
                    )
                } else {
                    LabeledContent("Target weight") {
                        Text(formattedWeight(draft.currentWeightKilograms))
                            .monospacedDigit()
                    }
                }
            }

            Section {
                Stepper("Age: \(draft.age)", value: $draft.age, in: 19...78)
                    .accessibilityIdentifier("calculated-age")

                if draft.measurementSystem == .metric {
                    measurementField(
                        title: "Height",
                        value: $draft.heightCentimeters,
                        unit: "cm",
                        focus: .heightCentimeters,
                        identifier: "calculated-height-centimeters"
                    )
                } else {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Feet", value: heightFeetBinding, format: .number)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .heightFeet)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 70)
                            .accessibilityIdentifier("calculated-height-feet")
                        Text("ft")
                            .foregroundStyle(.secondary)
                        TextField(
                            "Inches",
                            value: heightInchesBinding,
                            format: .number.precision(.fractionLength(0...1))
                        )
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .heightInches)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 76)
                        .accessibilityIdentifier("calculated-height-inches")
                        Text("in")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Age and height")
            } footer: {
                Text("Age, height, and current weight are required by the resting-energy equation.")
            }

            if let message = bodyValidationMessage {
                validationSection(message)
            }
        }
    }

    private var equationPage: some View {
        Form {
            progressSection
            Section {
                Text("Mifflin–St Jeor publishes separate female and male constants. Choose which published equation to use; this is not recorded as your gender identity.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Why this is asked")
            }
            Section {
                ForEach(CalorieEquation.allCases, id: \.self) { equation in
                    selectionRow(
                        title: equation.title,
                        detail: equation == .female
                            ? "Uses the published −161 constant"
                            : "Uses the published +5 constant",
                        selected: draft.equation == equation,
                        identifier: "calculated-equation-\(equation.rawValue)"
                    ) {
                        draft.equation = equation
                    }
                }
            } header: {
                Text("Choose equation input")
            } footer: {
                Text("Keep a manual goal if neither published equation fits.")
            }

            Section("Formula") {
                Text("10 × weight (kg) + 6.25 × height (cm) − 5 × age + selected constant")
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    private var activityPage: some View {
        Form {
            progressSection
            Section {
                Text("Daily routine estimates movement outside planned exercise. Excluding workouts and tracker calories avoids counting them twice.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Why routine is needed")
            }
            Section {
                ForEach(PlanActivityLevel.allCases, id: \.self) { level in
                    selectionRow(
                        title: "\(level.title) · \(level.factor.formatted(.number.precision(.fractionLength(2))))×",
                        detail: level.detail,
                        selected: draft.activityLevel == level,
                        identifier: "calculated-activity-\(level.rawValue)"
                    ) {
                        draft.activityLevel = level
                    }
                }
            } header: {
                Text("Choose your usual daily routine")
            } footer: {
                Text("Count Calories does not yet add exercise calories to this estimate.")
            }
        }
    }

    private var pacePage: some View {
        Form {
            progressSection

            Section {
                Picker("Plan by", selection: $draft.paceBasis) {
                    Text("Weekly rate").tag(PlanPaceBasis.weeklyRate)
                    Text("Target date").tag(PlanPaceBasis.targetDate)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("calculated-pace-basis")
            }

            if draft.paceBasis == .weeklyRate {
                Section {
                    ForEach([0.25, 0.5], id: \.self) { rate in
                        selectionRow(
                            title: formattedWeeklyRate(rate),
                            detail: rate == 0.25 ? "Gentler change" : "Faster supported change",
                            selected: abs(draft.weeklyRateKilograms - rate) < 0.000_001,
                            identifier: rate == 0.25
                                ? "calculated-rate-gentle"
                                : "calculated-rate-faster"
                        ) {
                            draft.weeklyRateKilograms = rate
                        }
                    }
                } header: {
                    Text("Preferred weekly change")
                } footer: {
                    Text("Forecast uses a rough static planning conversion. Real weight change is not linear or guaranteed.")
                }
            } else {
                Section {
                    DatePicker(
                        "Desired target date",
                        selection: $draft.targetDate,
                        in: calendar.date(byAdding: .day, value: 1, to: .now)!...,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("calculated-target-date")
                } footer: {
                    Text("A date that needs more than 0.5 kg per week is declined instead of producing an extreme calorie goal.")
                }
            }

            if let evaluationMessage = paceEvaluationMessage {
                validationSection(evaluationMessage)
            } else if case .recommendation(let plan) = evaluation,
                      let forecastDate = plan.forecastDate {
                Section("Planning forecast") {
                    LabeledContent("Estimated date") {
                        Text(forecastDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    LabeledContent("Effective rate") {
                        Text(formattedWeeklyRate(plan.effectiveWeeklyRateKilograms))
                    }
                }
            }
        }
    }

    private var reviewPage: some View {
        Form {
            progressSection

            switch evaluation {
            case .recommendation(let plan):
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Estimated daily goal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(plan.calorieGoal.formatted()) kcal")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                        Text("Starting estimate · rounded to nearest 10 kcal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("calculated-review-goal")
                }

                Section("Calculation breakdown") {
                    LabeledContent("Equation", value: plan.input.equation.title)
                    LabeledContent("Current weight") {
                        Text(formattedWeight(plan.input.currentWeightKilograms))
                            .monospacedDigit()
                    }
                    LabeledContent("Height") {
                        Text(formattedHeight(plan.input.heightCentimeters))
                            .monospacedDigit()
                    }
                    LabeledContent("Age", value: plan.input.age.formatted())
                    breakdownRow("Resting estimate", calories: plan.restingCalories)
                    LabeledContent("Daily routine") {
                        Text("\(plan.activityFactor.formatted(.number.precision(.fractionLength(2))))×")
                            .monospacedDigit()
                    }
                    breakdownRow("Estimated maintenance", calories: plan.maintenanceCalories)
                    if plan.input.goalMode != .maintain {
                        breakdownRow(
                            plan.input.goalMode == .lose ? "Rate adjustment" : "Rate addition",
                            calories: plan.dailyAdjustmentCalories,
                            signed: plan.input.goalMode == .lose ? "−" : "+"
                        )
                    }
                }

                if let forecastDate = plan.forecastDate {
                    Section {
                        LabeledContent("Target") {
                            Text(formattedWeight(plan.input.targetWeightKilograms))
                        }
                        LabeledContent("Weekly change") {
                            Text(formattedWeeklyRate(plan.effectiveWeeklyRateKilograms))
                        }
                        LabeledContent("Estimated date") {
                            Text(forecastDate.formatted(date: .abbreviated, time: .omitted))
                        }
                    } header: {
                        Text("Planning forecast")
                    } footer: {
                        Text("Date is a rough static forecast, not a promise. Weight change varies over time.")
                    }
                }

                Section("Method and limits") {
                    Text("Mifflin–St Jeor resting estimate × selected routine factor, then a 7,700 kcal/kg static pace adjustment.")
                    Text("This is an estimate for the supported adult scope—not medical advice. You can override or restore it later.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link(
                        "Mifflin–St Jeor study",
                        destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!
                    )
                }

            case .unsupported(let issue):
                Section {
                    Label(issueMessage(issue), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("calculated-review-unsupported")
                } header: {
                    Text("No calculated goal")
                } footer: {
                    Text("Your current manual goal stays unchanged. Go back to revise inputs or close setup.")
                }
            }
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 8) {
            if draft.step == .review {
                Button("Use calculated goal", action: applyRecommendation)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(recommendation == nil)
                    .accessibilityIdentifier("use-calculated-goal")
                Button(keepCurrentGoalTitle, action: keepCurrentGoal)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("keep-manual-goal")
            } else {
                Button("Continue", action: goForward)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(!canContinue)
                    .accessibilityIdentifier("calculated-setup-continue")

                if draft.step == .welcome {
                    Button(keepCurrentGoalTitle, action: keepCurrentGoal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("keep-manual-goal")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var progressSection: some View {
        Section {
            ProgressView(value: progress)
                .accessibilityLabel("Setup progress")
                .accessibilityValue("Step \(stepNumber) of \(stepCount)")
        }
        .listRowBackground(Color.clear)
    }

    private func selectionRow(
        title: String,
        detail: String,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .blue : .secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private func measurementField(
        title: String,
        value: Binding<Double>,
        unit: String,
        focus: NumericField,
        identifier: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(
                title,
                value: value,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: focus)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 110)
            .accessibilityIdentifier(identifier)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func validationSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private func breakdownRow(
        _ title: String,
        calories: Double,
        signed: String = ""
    ) -> some View {
        LabeledContent(title) {
            Text("\(signed)\(calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                .monospacedDigit()
        }
    }

    private var currentWeightBinding: Binding<Double> {
        convertedWeightBinding(\.currentWeightKilograms)
    }

    private var targetWeightBinding: Binding<Double> {
        convertedWeightBinding(\.targetWeightKilograms)
    }

    private func convertedWeightBinding(
        _ keyPath: WritableKeyPath<CaloriePlanSetupDraft, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                let kilograms = draft[keyPath: keyPath]
                return draft.measurementSystem == .metric
                    ? kilograms
                    : PlanUnitConversion.pounds(fromKilograms: kilograms)
            },
            set: { value in
                draft[keyPath: keyPath] = draft.measurementSystem == .metric
                    ? value
                    : PlanUnitConversion.kilograms(fromPounds: value)
                if keyPath == \.currentWeightKilograms, draft.goalMode == .maintain {
                    draft.targetWeightKilograms = draft.currentWeightKilograms
                }
            }
        )
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { Int(PlanUnitConversion.inches(fromCentimeters: draft.heightCentimeters) / 12) },
            set: { feet in
                let totalInches = Double(max(0, feet) * 12) + heightInchesBinding.wrappedValue
                draft.heightCentimeters = PlanUnitConversion.centimeters(fromInches: totalInches)
            }
        )
    }

    private var heightInchesBinding: Binding<Double> {
        Binding(
            get: {
                PlanUnitConversion.inches(fromCentimeters: draft.heightCentimeters)
                    .truncatingRemainder(dividingBy: 12)
            },
            set: { inches in
                let normalizedInches = min(max(0, inches), 11.9)
                let totalInches = Double(heightFeetBinding.wrappedValue * 12) + normalizedInches
                draft.heightCentimeters = PlanUnitConversion.centimeters(fromInches: totalInches)
            }
        )
    }

    private var evaluation: CaloriePlanEvaluation {
        guard draft.eligibilityConfirmed, let input = draft.input() else {
            return .unsupported(.invalidCalculation)
        }
        return CalculatedCaloriePlanCalculator.evaluate(
            input,
            now: .now,
            calendar: calendar
        )
    }

    private var recommendation: CalculatedCaloriePlan? {
        guard case .recommendation(let plan) = evaluation else { return nil }
        return plan
    }

    private var bodyValidationMessage: String? {
        guard CalculatedCaloriePlanCalculator.supportedAgeRange.contains(draft.age) else {
            return "Calculated setup supports ages 19–78."
        }
        guard
            CalculatedCaloriePlanCalculator.supportedWeightRange.contains(draft.currentWeightKilograms),
            CalculatedCaloriePlanCalculator.supportedWeightRange.contains(draft.targetWeightKilograms)
        else {
            return "Enter weights from 20 to 500 kg (44 to 1,102 lb)."
        }
        guard CalculatedCaloriePlanCalculator.supportedHeightRange.contains(draft.heightCentimeters) else {
            return "Enter a height from 100 to 250 cm (3 ft 3 in to 8 ft 2 in)."
        }
        guard let goalMode = draft.goalMode else { return "Choose a goal first." }
        switch goalMode {
        case .lose where draft.targetWeightKilograms >= draft.currentWeightKilograms:
            return "For weight loss, choose a target below current weight."
        case .gain where draft.targetWeightKilograms <= draft.currentWeightKilograms:
            return "For weight gain, choose a target above current weight."
        default:
            break
        }
        let target = goalMode == .maintain
            ? draft.currentWeightKilograms
            : draft.targetWeightKilograms
        guard
            CalculatedCaloriePlanCalculator.bodyMassIndex(
                kilograms: draft.currentWeightKilograms,
                heightCentimeters: draft.heightCentimeters
            ) >= CalculatedCaloriePlanCalculator.minimumBMI,
            CalculatedCaloriePlanCalculator.bodyMassIndex(
                kilograms: target,
                heightCentimeters: draft.heightCentimeters
            ) >= CalculatedCaloriePlanCalculator.minimumBMI
        else {
            return "Calculated setup does not support a current or target BMI below 18.5. Keep a manual goal and seek qualified guidance."
        }
        return nil
    }

    private var paceEvaluationMessage: String? {
        guard case .unsupported(let issue) = evaluation else { return nil }
        switch issue {
        case .targetDateTooSoon, .targetDateNotFuture, .invalidRate,
             .resultBelowMinimum, .resultAboveMaximum:
            return issueMessage(issue)
        default:
            return nil
        }
    }

    private var canContinue: Bool {
        switch draft.step {
        case .welcome:
            draft.eligibilityConfirmed
        case .goal:
            draft.goalMode != nil
        case .body:
            bodyValidationMessage == nil
        case .equation:
            draft.equation != nil
        case .activity:
            draft.activityLevel != nil
        case .pace:
            recommendation != nil
        case .review:
            false
        }
    }

    private var keepCurrentGoalTitle: String {
        profile?.planGoalSource == .calculated || profile?.planGoalSource == .adapted
            ? "Keep current goal"
            : "Keep manual goal"
    }

    private var navigationTitle: String {
        switch draft.step {
        case .welcome: "Welcome"
        case .goal: "Goal"
        case .body: "Body Details"
        case .equation: "Equation"
        case .activity: "Daily Routine"
        case .pace: "Pace"
        case .review: "Review Plan"
        }
    }

    private var stepNumber: Int {
        switch draft.step {
        case .welcome, .goal: 1
        case .body: 2
        case .equation: 3
        case .activity: 4
        case .pace: 5
        case .review: draft.goalMode == .maintain ? 5 : 6
        }
    }

    private var stepCount: Int {
        draft.goalMode == .maintain ? 5 : 6
    }

    private var progress: Double {
        Double(stepNumber) / Double(stepCount)
    }

    private func goalDetail(_ mode: PlanGoalMode) -> String {
        switch mode {
        case .lose: "Estimate maintenance, then subtract a bounded pace adjustment"
        case .maintain: "Estimate calories for a stable starting weight"
        case .gain: "Estimate maintenance, then add a bounded pace adjustment"
        }
    }

    private func selectGoalMode(_ mode: PlanGoalMode) {
        draft.goalMode = mode
        switch mode {
        case .lose:
            if draft.targetWeightKilograms >= draft.currentWeightKilograms {
                draft.targetWeightKilograms = max(20, draft.currentWeightKilograms - 2)
            }
        case .maintain:
            draft.targetWeightKilograms = draft.currentWeightKilograms
        case .gain:
            if draft.targetWeightKilograms <= draft.currentWeightKilograms {
                draft.targetWeightKilograms = min(500, draft.currentWeightKilograms + 2)
            }
        }
    }

    private func goForward() {
        focusedField = nil
        switch draft.step {
        case .welcome:
            draft.step = .goal
        case .goal:
            draft.step = .body
        case .body:
            draft.step = .equation
        case .equation:
            draft.step = .activity
        case .activity:
            draft.step = draft.goalMode == .maintain ? .review : .pace
        case .pace:
            draft.step = .review
        case .review:
            break
        }
        persist(status: .inProgress)
    }

    private func goBack() {
        focusedField = nil
        switch draft.step {
        case .welcome:
            break
        case .goal:
            draft.step = .welcome
        case .body:
            draft.step = .goal
        case .equation:
            draft.step = .body
        case .activity:
            draft.step = .equation
        case .pace:
            draft.step = .activity
        case .review:
            draft.step = draft.goalMode == .maintain ? .activity : .pace
        }
        persist(status: .inProgress)
    }

    private func closeAndResumeLater() {
        let operation = AppLogger.begin(
            "plan_setup.save_draft",
            category: .userAction,
            source: "calculated_setup"
        )
        guard persist(status: .inProgress) else {
            AppLogger.partial(operation, failedComponent: "draft_store")
            return
        }
        if profile == nil {
            modelContext.insert(UserProfile())
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                AppLogger.fail(operation, error: error, rollback: "succeeded")
                errorMessage = "Setup progress could not be saved. Try again."
                return
            }
        }
        dismiss()
        onFinish()
        AppLogger.succeed(operation)
    }

    private func keepCurrentGoal() {
        let operation = AppLogger.begin(
            "plan_setup.keep_current",
            category: .userAction,
            source: "calculated_setup"
        )
        if profile != nil {
            guard persist(status: .skipped) else {
                AppLogger.partial(operation, failedComponent: "draft_store")
                return
            }
            dismiss()
            onFinish()
            AppLogger.succeed(operation)
            return
        }

        guard persist(status: .skipped) else {
            AppLogger.partial(operation, failedComponent: "draft_store")
            return
        }
        modelContext.insert(UserProfile())
        do {
            try modelContext.save()
            dismiss()
            onFinish()
            AppLogger.succeed(operation)
        } catch {
            modelContext.rollback()
            _ = persist(status: .inProgress)
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = "Your current plan could not be prepared. Try again."
        }
    }

    private func applyRecommendation() {
        guard let recommendation else { return }
        let operation = AppLogger.begin(
            "plan_setup.apply",
            category: .userAction,
            source: "calculated_setup"
        )
        do {
            guard let mutationCoordinator else {
                throw PlanEvidenceMutationError.coordinatorUnavailable
            }
            mutationCoordinator.synchronizeCalendar(calendar)
            _ = try mutationCoordinator.acceptCalculatedPlan(
                recommendation,
                measurementSystem: draft.measurementSystem
            )
            let setupRecordSaved = persist(status: .completed)
            dismiss()
            onFinish()
            if setupRecordSaved {
                AppLogger.succeed(operation)
            } else {
                AppLogger.partial(operation, failedComponent: "draft_store")
            }
        } catch {
            modelContext.rollback()
            AppLogger.fail(operation, error: error, rollback: "succeeded")
            errorMessage = "Calculated plan was not saved. Your manual goal is unchanged."
        }
    }

    @discardableResult
    private func persist(status: CaloriePlanSetupStatus) -> Bool {
        let saved = CaloriePlanSetupStore.save(CaloriePlanSetupRecord(
            status: status,
            draft: draft,
            acceptedPlanDateAtStart: acceptedPlanDateAtStart
        ))
        if !saved {
            let operation = AppLogger.begin(
                "plan_setup.draft_persist",
                category: .persistence,
                source: "calculated_setup"
            )
            AppLogger.partial(operation, failedComponent: "encoding")
            errorMessage = "Setup progress could not be saved. Try again."
        }
        return saved
    }

    private func issueMessage(_ issue: CaloriePlanIssue) -> String {
        switch issue {
        case .invalidAge:
            "Calculated setup supports ages 19–78."
        case .invalidWeight:
            "Enter valid current and target weights."
        case .invalidHeight:
            "Enter a valid height."
        case .invalidGoalRelationship:
            "Current and target weights do not match the selected goal."
        case .belowSupportedBMI:
            "Calculated setup does not support a current or target BMI below 18.5. Keep a manual goal and seek qualified guidance."
        case .invalidRate:
            "Choose a weekly change of 0.25 or 0.5 kg."
        case .targetDateNotFuture:
            "Choose a future target date."
        case .targetDateTooSoon(let earliest):
            "That date would need more than 0.5 kg per week. Choose \(earliest.formatted(date: .abbreviated, time: .omitted)) or later."
        case .resultBelowMinimum:
            "This pace would put the estimate below 1,000 kcal/day. Choose a gentler rate, allow more time, or keep a manual goal."
        case .resultAboveMaximum:
            "This estimate is above Count Calories’ 5,000 kcal input range. Keep a manual goal or seek qualified guidance."
        case .invalidCalculation:
            "Complete every required input to review an estimate."
        }
    }

    private func formattedWeight(_ kilograms: Double) -> String {
        if draft.measurementSystem == .metric {
            return "\(kilograms.formatted(.number.precision(.fractionLength(1)))) kg"
        }
        let pounds = PlanUnitConversion.pounds(fromKilograms: kilograms)
        return "\(pounds.formatted(.number.precision(.fractionLength(1)))) lb"
    }

    private func formattedHeight(_ centimeters: Double) -> String {
        if draft.measurementSystem == .metric {
            return "\(centimeters.formatted(.number.precision(.fractionLength(0...1)))) cm"
        }
        let totalInches = PlanUnitConversion.inches(fromCentimeters: centimeters)
        let feet = Int(totalInches / 12)
        let inches = totalInches - Double(feet * 12)
        return "\(feet) ft \(inches.formatted(.number.precision(.fractionLength(0...1)))) in"
    }

    private func formattedWeeklyRate(_ kilograms: Double) -> String {
        if draft.measurementSystem == .metric {
            return "\(kilograms.formatted(.number.precision(.fractionLength(0...2)))) kg/week"
        }
        let pounds = PlanUnitConversion.pounds(fromKilograms: kilograms)
        return "\(pounds.formatted(.number.precision(.fractionLength(0...1)))) lb/week"
    }
}

extension CaloriePlanSetupDraft {
    static func prefilled(from profile: UserProfile) -> CaloriePlanSetupDraft {
        if let stored = profile.storedCalculatedPlan {
            let input = stored.plan.input
            return CaloriePlanSetupDraft(
                step: .welcome,
                measurementSystem: stored.measurementSystem,
                goalMode: input.goalMode,
                currentWeightKilograms: input.currentWeightKilograms,
                targetWeightKilograms: input.targetWeightKilograms,
                age: input.age,
                heightCentimeters: input.heightCentimeters,
                equation: input.equation,
                activityLevel: input.activityLevel,
                paceBasis: input.paceBasis,
                weeklyRateKilograms: input.weeklyRateKilograms,
                targetDate: input.targetDate ?? stored.plan.forecastDate ?? profile.targetDate,
                eligibilityConfirmed: false
            )
        }

        return CaloriePlanSetupDraft(
            step: .welcome,
            measurementSystem: .metric,
            goalMode: nil,
            currentWeightKilograms: profile.currentWeight,
            targetWeightKilograms: profile.targetWeight,
            age: profile.age,
            heightCentimeters: 0,
            equation: nil,
            activityLevel: nil,
            paceBasis: .weeklyRate,
            weeklyRateKilograms: 0.25,
            targetDate: profile.targetDate,
            eligibilityConfirmed: false
        )
    }
}

#if DEBUG || RELEASE_VALIDATION
#Preview("Calculated setup") {
    CaloriePlanSetupView(
        profile: UserProfile(),
        record: CaloriePlanSetupRecord(
            status: .notStarted,
            draft: CaloriePlanSetupDraft()
        ),
        onFinish: {}
    )
    .previewPlanEvidenceContainer(PreviewData.makeContainer())
}

#Preview("Calculated setup — Body") {
    var draft = CaloriePlanSetupDraft()
    draft.step = .body
    draft.goalMode = .lose
    draft.heightCentimeters = 170
    draft.eligibilityConfirmed = true
    return CaloriePlanSetupView(
        profile: UserProfile(),
        record: CaloriePlanSetupRecord(status: .inProgress, draft: draft),
        onFinish: {}
    )
    .previewPlanEvidenceContainer(PreviewData.makeContainer())
}

#Preview("Calculated setup — Infeasible date") {
    var draft = CaloriePlanSetupDraft()
    draft.step = .pace
    draft.goalMode = .lose
    draft.equation = .female
    draft.activityLevel = .low
    draft.paceBasis = .targetDate
    draft.targetDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    draft.eligibilityConfirmed = true
    return CaloriePlanSetupView(
        profile: UserProfile(),
        record: CaloriePlanSetupRecord(status: .inProgress, draft: draft),
        onFinish: {}
    )
    .previewPlanEvidenceContainer(PreviewData.makeContainer())
}

#Preview("Calculated setup review") {
    var draft = CaloriePlanSetupDraft()
    draft.step = .review
    draft.goalMode = .lose
    draft.equation = .female
    draft.activityLevel = .low
    draft.eligibilityConfirmed = true
    return CaloriePlanSetupView(
        profile: UserProfile(),
        record: CaloriePlanSetupRecord(status: .inProgress, draft: draft),
        onFinish: {}
    )
    .previewPlanEvidenceContainer(PreviewData.makeContainer())
}
#endif
