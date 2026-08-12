import SwiftData
import SwiftUI
import os

struct AdaptivePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.planEvidenceMutationCoordinator) private var mutationCoordinator
    @Environment(\.calendar) private var calendar
    @Query(sort: \FoodLogCompletion.attestedAt, order: .reverse) private var completions: [FoodLogCompletion]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]

    let profile: UserProfile
    let onReviewCalculatedSetup: () -> Void

    @State private var supportedScopeConfirmed = false
    @State private var evaluationResult: PlanEvidenceEvaluationResult?
    @State private var errorMessage: String?
    @State private var retryAction: (() -> Void)?
    @State private var confirmingProposal: AdaptivePlanProposalRecord?
    @State private var confirmingDecline: AdaptivePlanProposalRecord?
    @State private var confirmingRevert: AdaptivePlanProposalRecord?
    @State private var confirmingDisable = false

    private var persistenceState: AdaptivePlanPersistenceState? { profile.adaptivePlanState }
    private var checkInsEnabled: Bool { persistenceState?.checkInsEnabled == true }

    private var currentAppliedProposal: AdaptivePlanProposalRecord? {
        guard let proposal = persistenceState?.latestAppliedProposal,
              profile.currentPlanRevisionID == proposal.appliedRevisionID else { return nil }
        return proposal
    }

    private var yesterday: Date? {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))
    }

    private var yesterdayCompletion: FoodLogCompletion? {
        guard let yesterday else { return nil }
        return completions.first { completion in
            completion.calendarIdentifier == String(describing: calendar.identifier)
                && completion.timeZoneIdentifier == calendar.timeZone.identifier
                && completion.dayStart == yesterday
        }
    }

    private var evidenceWindowDays: [Date] {
        guard let yesterday else { return [] }
        return (0..<AdaptiveCaloriePlanEvaluator.evidenceWindowDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: yesterday)
        }.reversed()
    }

    private var eligibleCompletionDays: Set<Date> {
        guard let epoch = persistenceState?.epoch else { return [] }
        let calendarIdentifier = String(describing: calendar.identifier)
        return Set(completions.compactMap { completion in
            guard !completion.isStale,
                  completion.calendarIdentifier == calendarIdentifier,
                  completion.timeZoneIdentifier == calendar.timeZone.identifier,
                  completion.attestedAt >= epoch.startedAt,
                  completion.dayStart >= epoch.startDay else { return nil }
            return completion.dayStart
        })
    }

    private var missingFoodLogDays: [Date] {
        evidenceWindowDays.filter { !eligibleCompletionDays.contains($0) }
    }

    private var relevantWeightDays: [Date] {
        guard let epoch = persistenceState?.epoch,
              let first = evidenceWindowDays.first,
              let last = evidenceWindowDays.last else { return [] }
        return Set(weights.compactMap { weight in
            guard weight.date.timeIntervalSinceReferenceDate.isFinite,
                  weight.kilograms.isFinite,
                  (20...500).contains(weight.kilograms),
                  weight.date >= epoch.startedAt else { return nil }
            let day = calendar.startOfDay(for: weight.date)
            return day >= first && day <= last ? day : nil
        }).sorted()
    }

    private var firstExcessiveWeightGap: (start: Date, end: Date, days: Int)? {
        for (start, end) in zip(relevantWeightDays, relevantWeightDays.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: start, to: end).day ?? Int.max
            if gap > 10 { return (start, end, gap) }
        }
        return nil
    }

    private var earliestPossibleCheckInDate: Date? {
        guard let epoch = persistenceState?.epoch else { return nil }
        let today = calendar.startOfDay(for: .now)
        var consecutiveCompleteDays = 0
        for day in evidenceWindowDays.reversed() {
            guard eligibleCompletionDays.contains(day) else { break }
            consecutiveCompleteDays += 1
        }
        guard let foodCandidate = calendar.date(
            byAdding: .day,
            value: AdaptiveCaloriePlanEvaluator.foodDayRequirement - consecutiveCompleteDays,
            to: today
        ), let epochCandidate = calendar.date(
            byAdding: .day,
            value: AdaptiveCaloriePlanEvaluator.foodDayRequirement,
            to: epoch.startDay
        ) else { return nil }
        return max(foodCandidate, epochCandidate)
    }

    private var canReviewYesterday: Bool {
        guard let yesterday, let epoch = persistenceState?.epoch else { return false }
        return yesterday >= epoch.startDay
            && (yesterdayCompletion == nil || yesterdayCompletion?.isStale == true)
    }

    private var recentAcceptedStepMagnitude: Int {
        let today = calendar.startOfDay(for: .now)
        guard let firstDay = calendar.date(byAdding: .day, value: -27, to: today) else { return 0 }
        return persistenceState?.acceptedSteps.reduce(into: 0) { total, step in
            let day = calendar.startOfDay(for: step.effectiveDate)
            guard day >= firstDay, day <= today, step.calories != Int.min else { return }
            total += abs(step.calories)
        } ?? 0
    }

    private var currentProposalStepLimit: Int {
        min(100, max(0, 200 - recentAcceptedStepMagnitude))
    }

    private var displayedPlanSource: PlanGoalSource {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-adaptive-applied"),
           currentAppliedProposal != nil {
            return .adapted
        }
#endif
        return profile.planGoalSource
    }

    var body: some View {
        List {
            Section("Current goal") {
                LabeledContent("Daily goal") {
                    Text("\(profile.dailyCalorieGoal.formatted()) kcal")
                        .monospacedDigit()
                }
                .accessibilityIdentifier("adaptive-current-calorie-goal")
                LabeledContent("Source", value: planGoalSourceTitle(displayedPlanSource))
                    .accessibilityIdentifier("adaptive-plan-source")
            }

            if profile.planGoalSource == .manual || profile.planGoalSource == .unknown {
                reviewedSetupSection
            } else {
                if let applied = currentAppliedProposal {
                    appliedSection(applied)
                }
                if !checkInsEnabled {
                    offSection
                } else if let pending = pendingProposal {
                    proposalSection(pending)
                } else {
                    statusSection
                }
            }

            if checkInsEnabled {
                disableSection
            }
            methodSection
        }
        .navigationTitle("Goal check-ins")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("adaptive-plan-view")
        .task { refresh() }
        .alert("Could not update goal check-ins", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            if retryAction != nil {
                Button("Try again") {
                    retryAction?()
                }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
                .accessibilityIdentifier("adaptive-transaction-error")
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmingProposal != nil },
                set: { if !$0 { confirmingProposal = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let proposal = confirmingProposal {
                Button("Use \(proposal.proposedGoal.formatted()) kcal") {
                    apply(proposal)
                }
                Button("Cancel", role: .cancel) {
                    confirmingProposal = nil
                }
            }
        } message: {
            if let proposal = confirmingProposal {
                Text("Changes today’s and future goal from \(proposal.currentGoal.formatted()) to \(proposal.proposedGoal.formatted()) kcal. Today’s accepted revision becomes the goal context for this whole civil day. Food and weight logs stay unchanged.")
            }
        }
        .confirmationDialog(
            revertConfirmationTitle,
            isPresented: Binding(
                get: { confirmingRevert != nil },
                set: { if !$0 { confirmingRevert = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let proposal = confirmingRevert,
               let previous = proposal.preApplySnapshot {
                Button("Revert to \(previous.calories.formatted()) kcal", role: .destructive) {
                    confirmingRevert = nil
                    revert(proposal)
                }
                .accessibilityIdentifier("confirm-revert-adaptive-proposal")
                Button("Keep \(profile.dailyCalorieGoal.formatted()) kcal", role: .cancel) {
                    confirmingRevert = nil
                }
            }
        } message: {
            if let previous = confirmingRevert?.preApplySnapshot {
                Text("Reverts current \(profile.dailyCalorieGoal.formatted()) kcal goal to prior \(previous.calories.formatted()) kcal goal. Food and weight logs stay unchanged. If goal check-ins stay enabled, this starts a fresh evidence period and current collection progress cannot be reused.")
            }
        }
        .alert(
            "Disable goal check-ins?",
            isPresented: $confirmingDisable
        ) {
            Button("Disable goal check-ins", role: .destructive) {
                disable()
            }
            Button("Keep enabled", role: .cancel) {}
        } message: {
            Text("Your current goal and all food, weight, and check-in history stay unchanged. Re-enabling starts a new evidence period, so current collection progress cannot be resumed.")
        }
        .confirmationDialog(
            "Decline this check-in?",
            isPresented: Binding(
                get: { confirmingDecline != nil },
                set: { if !$0 { confirmingDecline = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let proposal = confirmingDecline {
                Button("Decline proposal", role: .destructive) {
                    confirmingDecline = nil
                    decline(proposal)
                }
                Button("Keep reviewing", role: .cancel) {
                    confirmingDecline = nil
                }
            }
        } message: {
            Text("Your goal stays unchanged. This proposal becomes unavailable; another check-in needs seven local days, seven new complete food days, and a later weigh-in.")
        }
    }

    private var pendingProposal: AdaptivePlanProposalRecord? {
        if case .pending(let proposal) = evaluationResult { return proposal }
        return persistenceState?.pendingProposal
    }

    private var confirmationTitle: String {
        guard let proposal = confirmingProposal else { return "Use proposal?" }
        return "Use \(proposal.proposedGoal.formatted()) kcal?"
    }

    private var revertConfirmationTitle: String {
        guard let previous = confirmingRevert?.preApplySnapshot else { return "Revert adapted goal?" }
        return "Revert \(profile.dailyCalorieGoal.formatted()) kcal to \(previous.calories.formatted()) kcal?"
    }

    private var reviewedSetupSection: some View {
        Section {
            Text(profile.planGoalSource == .unknown
                 ? "Unknown source is preserved. Goal check-ins cannot evaluate or propose a change."
                 : "Manual goals are never adapted automatically.")
                .foregroundStyle(.secondary)
            Button("Review calculated setup", action: onReviewCalculatedSetup)
                .frame(minHeight: 44)
                .accessibilityIdentifier("adaptive-review-calculated-setup")
        } header: {
            Text("Check-ins paused")
        } footer: {
            Text("Complete reviewed calculated setup before enabling check-ins. No proposal is available for this source.")
        }
    }

    private var offSection: some View {
        Section {
            Text("Goal check-ins run on this device after six consecutive weeks: all 42 days need an explicitly complete food log, plus distributed weigh-ins.")
                .foregroundStyle(.secondary)
            Toggle(
                "I confirm this is not for pregnancy, breastfeeding, clinical nutrition care, or another unsupported use.",
                isOn: $supportedScopeConfirmed
            )
            .accessibilityIdentifier("adaptive-supported-scope-confirmation")
            Button("Enable goal check-ins", action: enable)
                .frame(minHeight: 44)
                .disabled(!supportedScopeConfirmed)
                .accessibilityIdentifier("enable-adaptive-check-ins")
        } header: {
            Text("Check-ins off")
        } footer: {
            Text("Enabling starts a new evidence period. Existing food, weight, and check-in history remain on this device.")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch evaluationResult {
        case .none:
            Section {
                ProgressView("Reviewing on-device evidence")
            } header: {
                Text("Check-in status")
            }
        case .cadence(let nextEligibleDay):
            Section {
                Label("Paused until \(nextEligibleDay.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    .accessibilityIdentifier("adaptive-cadence-status")
                Text("A new check-in needs seven new complete days and a later weigh-in after last decision.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Check-in status")
            }
        case .evaluation(let evaluation):
            evaluationSection(evaluation)
        case .pending(let proposal):
            proposalSection(proposal)
        }
    }

    private var disableSection: some View {
        Section {
            Button("Disable goal check-ins", role: .destructive) {
                confirmingDisable = true
            }
            .frame(minHeight: 44)
                .accessibilityIdentifier("disable-adaptive-check-ins")
        } footer: {
            Text("Disabling preserves the current goal plus food, weight, and check-in history. Re-enabling starts a new evidence period.")
        }
    }

    @ViewBuilder
    private func evaluationSection(_ evaluation: AdaptiveCaloriePlanEvaluation) -> some View {
        switch evaluation {
        case .collecting(let collection):
            Section {
                LabeledContent("Complete food days", value: "\(collection.completeFoodDays) of 42")
                LabeledContent("Weigh-in days", value: "\(collection.weighInDays) of at least 8")
                LabeledContent("Newest 28 days", value: "\(collection.newest28WeighInDays) of at least 6 weigh-ins")
                if let first = evidenceWindowDays.first, let last = evidenceWindowDays.last {
                    LabeledContent("Evidence window", value: dateRange(first, last))
                }
                if let earliestPossibleCheckInDate {
                    LabeledContent(
                        "Earliest possible check-in",
                        value: earliestPossibleCheckInDate.formatted(date: .abbreviated, time: .omitted)
                    )
                    .accessibilityIdentifier("adaptive-next-eligible-date")
                }
                if !missingFoodLogDays.isEmpty {
                    DisclosureGroup("Missing complete dates (\(missingFoodLogDays.count))") {
                        ForEach(missingFoodLogDays, id: \.self) { day in
                            Text(day.formatted(date: .complete, time: .omitted))
                        }
                    }
                    .accessibilityIdentifier("adaptive-missing-food-dates")
                }
                if let gap = firstExcessiveWeightGap {
                    Text("Weight gap: \(dateRange(gap.start, gap.end)) (\(gap.days) days).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if canReviewYesterday, let yesterday {
                    Button(yesterdayCompletion?.isStale == true ? "Reconfirm yesterday" : "Mark yesterday complete") {
                        markYesterdayComplete(yesterday)
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("mark-yesterday-food-log-complete")
                    .accessibilityHint("Includes yesterday only after you confirm its food log is finished.")
                }
                ForEach(Array(collection.missing.enumerated()), id: \.offset) { _, requirement in
                    Text(collectionRequirementText(requirement))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Collecting")
            } footer: {
                Text("A complete day means you explicitly marked its food log finished. Missing days are not treated as zero. Weight timing or later edits can move the earliest possible date.")
            }
        case .checkData(let check):
            Section {
                Text("Enough evidence may be present, but this estimate is not supported for a proposal yet.")
                Text(checkDataReasonText(check.reason))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let evidence = check.estimates {
                    evidenceRows(evidence)
                }
            } header: {
                Text("Check data")
            } footer: {
                Text("Food logs and scale weight can vary. This estimate cannot tell whether a difference comes from measurement noise, logging gaps, routine changes, or energy-needs uncertainty. It is general planning information, not medical advice.")
            }
        case .upToDate(let evidence):
            Section {
                Text("Evidence agrees and current goal is within check-in noise range.")
                evidenceRows(evidence)
            } header: {
                Text("Up to date")
            } footer: {
                Text("No automatic change occurs. Check-ins continue on weekly cadence when fresh evidence is available.")
            }
        case .proposal(let proposal):
            proposalSectionRecord(proposal)
        case .paused(let reason):
            Section {
                Text(pauseText(reason))
            } header: {
                Text("Paused")
            }
        }
    }

    private func proposalSection(_ proposal: AdaptivePlanProposalRecord) -> some View {
        Section {
            proposalDetails(
                currentGoal: proposal.currentGoal,
                currentSource: PlanGoalSource(rawValue: proposal.currentSourceRawValue) ?? .unknown,
                candidate: proposal.candidateCalories,
                rawDifference: proposal.rawDifferenceCalories,
                step: proposal.stepCalories,
                proposedGoal: proposal.proposedGoal,
                completeDays: proposal.completeFoodDays,
                weighIns: proposal.weighInDays,
                estimates: proposal.estimates,
                createdAt: proposal.createdAt,
                expiresAt: proposal.expiresAt
            )
            Button("Use \(proposal.proposedGoal.formatted()) kcal") {
                confirmingProposal = proposal
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("use-adaptive-proposal")
            Button("Decline this check-in", role: .destructive) {
                confirmingDecline = proposal
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("decline-adaptive-proposal")
            Button("Close") { dismiss() }
                .frame(minHeight: 44)
                .accessibilityIdentifier("close-adaptive-proposal")
        } header: {
            Text("Proposal ready")
        } footer: {
            Text("Decline keeps your goal and retires this proposal until fresh evidence is ready. Close keeps the proposal available. Food logs and scale weight can vary; this observed estimate cannot identify why they differ.")
        }
    }

    private func proposalSectionRecord(_ proposal: AdaptiveCalorieProposal) -> some View {
        Section {
            proposalDetails(
                currentGoal: profile.dailyCalorieGoal,
                currentSource: profile.planGoalSource,
                candidate: proposal.candidateCalories,
                rawDifference: proposal.rawDifferenceCalories,
                step: proposal.stepCalories,
                proposedGoal: proposal.proposedDailyGoal,
                completeDays: proposal.evidence.completeFoodDays,
                weighIns: proposal.evidence.weighInDays,
                estimates: proposal.evidence.estimates.map { AdaptiveWindowEstimateRecord($0) },
                createdAt: .now,
                expiresAt: .now
            )
            Text("Refreshing creates a persisted proposal before it can be used.")
                .foregroundStyle(.secondary)
        } header: {
            Text("Proposal ready")
        }
    }

    @ViewBuilder
    private func evidenceRows(_ evidence: AdaptiveCalorieEvidence) -> some View {
        ForEach(evidence.estimates, id: \.nominalDays) { estimate in
            LabeledContent(
                "\(estimate.nominalDays)-day observed maintenance",
                value: "\(estimate.observedMaintenanceCalories.formatted(.number.precision(.fractionLength(0)))) kcal"
            )
        }
        LabeledContent("Complete food days", value: "\(evidence.completeFoodDays) of 42")
        LabeledContent("Weigh-ins", value: "\(evidence.weighInDays) days")
    }

    private func proposalDetails(
        currentGoal: Int,
        currentSource: PlanGoalSource,
        candidate: Double,
        rawDifference: Double,
        step: Int,
        proposedGoal: Int,
        completeDays: Int,
        weighIns: Int,
        estimates: [AdaptiveWindowEstimateRecord],
        createdAt: Date,
        expiresAt: Date
    ) -> some View {
        Group {
            LabeledContent("Current goal", value: "\(currentGoal.formatted()) kcal · \(planGoalSourceTitle(currentSource))")
            LabeledContent("Full candidate", value: "\(candidate.formatted(.number.precision(.fractionLength(0)))) kcal")
            LabeledContent(
                "Observed difference",
                value: signedCalories(Int(rawDifference.rounded(.toNearestOrAwayFromZero)))
            )
            Text("Difference is outside the ±75 kcal noise range and no more than the 400 kcal review limit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledContent("Proposed step", value: signedCalories(step))
            LabeledContent("Proposed goal", value: "\(proposedGoal.formatted()) kcal")
                .accessibilityIdentifier("adaptive-proposed-goal")
            LabeledContent(
                "Change limits",
                value: "\(recentAcceptedStepMagnitude) of 200 kcal used in 28 days · \(currentProposalStepLimit) kcal maximum now"
            )
            .accessibilityIdentifier("adaptive-change-limits")
            LabeledContent("Complete food days", value: "\(completeDays) of 42")
            LabeledContent("Weigh-ins", value: "\(weighIns) days")
            ForEach(estimates, id: \.nominalDays) { estimate in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(estimate.nominalDays)-day observed maintenance")
                    Text("\(estimate.observedMaintenanceCalories.formatted(.number.precision(.fractionLength(0)))) kcal · trend \(signedWeightTrend(estimate.kilogramsPerDay * 7)) · \(estimate.trendStart.formatted(date: .abbreviated, time: .omitted))–\(estimate.trendEnd.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("Created", value: createdAt.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
            if let stored = profile.storedCalculatedPlan {
                LabeledContent("Retained pace", value: "\(stored.plan.dailyAdjustmentCalories.formatted(.number.precision(.fractionLength(0)))) kcal/day")
            }
        }
    }

    private func appliedSection(_ proposal: AdaptivePlanProposalRecord) -> some View {
        Section {
            Text("Adapted goal is active after your explicit check-in.")
            LabeledContent("Current goal", value: "\(profile.dailyCalorieGoal.formatted()) kcal")
                .accessibilityIdentifier("adaptive-current-calorie-goal")
            if let previous = proposal.preApplySnapshot {
                Button("Revert to \(previous.calories.formatted()) kcal") {
                    confirmingRevert = proposal
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("revert-adaptive-proposal")
            }
        } header: {
            Text("Applied")
        } footer: {
            Text("Revert restores exact prior goal and source. It does not change food or weight logs.")
        }
    }

    private var methodSection: some View {
        Section {
            DisclosureGroup("Formula and included days") {
                Text("Observed maintenance = mean complete-day intake − (smoothed weight trend × 7,700 kcal/kg). Count Calories compares 28-, 35-, and 42-day windows ending yesterday.")
                Text("Today is excluded. Each included day needs a complete, nonstale attestation. Weigh-ins are grouped by civil day and use a median for that day.")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("adaptive-method-disclosure")
        } header: {
            Text("Method")
        } footer: {
            Text("All evidence, estimates, proposals, and history stay on this device.")
        }
    }

    private func markYesterdayComplete(_ day: Date) {
        perform(retry: { markYesterdayComplete(day) }) {
            let coordinator = try requiredCoordinator()
            if yesterdayCompletion?.isStale == true {
                _ = try coordinator.reconfirmFoodLog(for: day)
            } else {
                _ = try coordinator.markFoodLogComplete(for: day)
            }
            refresh()
        }
    }

    private func enable() {
        perform(retry: enable) {
            let coordinator = try requiredCoordinator()
            _ = try coordinator.enableAdaptiveCheckIns(supportedScopeConfirmed: supportedScopeConfirmed)
            refresh()
        }
    }

    private func disable() {
        perform(retry: disable) {
            try requiredCoordinator().disableAdaptiveCheckIns()
            refresh()
        }
    }

    private func decline(_ proposal: AdaptivePlanProposalRecord) {
        perform(retry: { decline(proposal) }) {
            try requiredCoordinator().declinePendingProposal(id: proposal.id)
            refresh()
        }
    }

    private func apply(_ proposal: AdaptivePlanProposalRecord) {
        confirmingProposal = nil
        do {
            _ = try requiredCoordinator().applyPendingProposal(
                id: proposal.id,
                expectedPlanRevisionID: proposal.expectedPlanRevisionID,
                expectedEvidenceRevision: proposal.expectedEvidenceRevision,
                expectedEvidenceSignature: proposal.evidenceSignature
            )
            retryAction = nil
            refresh()
        } catch {
            AppLogger.persistence.error("Goal check-in apply failed: \(error.localizedDescription, privacy: .public)")
            if proposalNeedsRefresh(after: error) {
                do {
                    evaluationResult = try requiredCoordinator().evaluateCurrent()
                    retryAction = nil
                } catch {
                    retryAction = refresh
                }
                errorMessage = "This proposal was not applied because your plan or evidence changed. Review the updated status before choosing again."
            } else {
                retryAction = { apply(proposal) }
                errorMessage = "Your goal is unchanged. Please try again."
            }
        }
    }

    private func proposalNeedsRefresh(after error: Error) -> Bool {
        guard let mutationError = error as? PlanEvidenceMutationError else { return false }
        switch mutationError {
        case .compareAndSetFailed,
             .missingPendingProposal,
             .proposalNotCurrent,
             .proposalExpired,
             .evidenceSignatureChanged,
             .calendarOrTimeZoneChanged,
             .epochBasisChanged,
             .identityMigrationRequired,
             .unsupportedSource,
             .missingCalculatedBasis,
             .corruptAdaptivePayload,
             .unsupportedAdaptiveSchema:
            return true
        default:
            return false
        }
    }

    private func revert(_ proposal: AdaptivePlanProposalRecord) {
        guard let revisionID = proposal.appliedRevisionID else { return }
        perform(retry: { revert(proposal) }) {
            _ = try requiredCoordinator().revertAppliedProposal(appliedRevisionID: revisionID)
            refresh()
        }
    }

    private func refresh() {
        guard checkInsEnabled else {
            evaluationResult = nil
            return
        }
        do {
            evaluationResult = try requiredCoordinator().evaluateCurrent()
        } catch {
            errorMessage = "Goal check-ins could not be refreshed. Please try again."
            retryAction = refresh
            AppLogger.persistence.error("Failed to refresh goal check-ins: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func requiredCoordinator() throws -> PlanEvidenceMutationCoordinator {
        guard let mutationCoordinator else {
            throw PlanEvidenceMutationError.coordinatorUnavailable
        }
        mutationCoordinator.synchronizeCalendar(calendar)
        return mutationCoordinator
    }

    private func perform(retry: @escaping () -> Void, _ operation: () throws -> Void) {
        do {
            try operation()
            retryAction = nil
        } catch {
            retryAction = retry
            errorMessage = "Your goal is unchanged. Please try again."
            AppLogger.persistence.error("Goal check-in transaction failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

func planGoalSourceTitle(_ source: PlanGoalSource) -> String {
    switch source {
    case .manual: "Manual"
    case .calculated: "Calculated"
    case .adapted: "Adapted"
    case .unknown: "Unknown source"
    }
}

func planGoalSourceSummary(_ source: PlanGoalSource) -> String {
    switch source {
    case .manual: "Manual goal"
    case .calculated: "Calculated estimate"
    case .adapted: "Adapted from calculated basis"
    case .unknown: "Unknown source · check-ins paused"
    }
}

func adaptivePlanSummary(_ profile: UserProfile) -> String {
    guard profile.planGoalSource == .calculated || profile.planGoalSource == .adapted else {
        return "Paused"
    }
    guard let state = profile.adaptivePlanState else { return "Off" }
    if let proposal = state.pendingProposal { return "Proposal: \(proposal.proposedGoal.formatted()) kcal" }
    if state.latestAppliedProposal != nil, profile.planGoalSource == .adapted { return "Applied" }
    return state.checkInsEnabled ? "Check status" : "Off"
}

private extension AdaptivePlanView {
    func collectionRequirementText(_ requirement: AdaptiveCalorieCollectionRequirement) -> String {
        switch requirement {
        case .completeFoodDays:
            return "Mark each missing date complete; open the date list above for exact days."
        case .eightWeighInDays:
            return "Add at least 8 distinct weigh-in days in this evidence window."
        case .sixRecentWeighInDays:
            let newest = Array(evidenceWindowDays.suffix(28))
            guard let first = newest.first, let last = newest.last else {
                return "Add at least 6 weigh-in days in the newest 28 days."
            }
            return "Add at least 6 weigh-in days from \(dateRange(first, last))."
        case .weighInInSevenDayBlock(let block):
            let firstIndex = block * 7
            guard evidenceWindowDays.indices.contains(firstIndex),
                  evidenceWindowDays.indices.contains(firstIndex + 6) else {
                return "Add a weigh-in in week \(block + 1) of this six-week window."
            }
            return "Add a weigh-in from \(dateRange(evidenceWindowDays[firstIndex], evidenceWindowDays[firstIndex + 6]))."
        case .firstBoundary(let windowDays):
            let nominal = Array(evidenceWindowDays.suffix(windowDays))
            guard nominal.count >= 3 else {
                return "Add a weigh-in in first 3 days of the \(windowDays)-day window."
            }
            return "Add a weigh-in from \(dateRange(nominal[0], nominal[2])) for the \(windowDays)-day boundary."
        case .commonFinalBoundary:
            let finalDays = Array(evidenceWindowDays.suffix(3))
            guard let first = finalDays.first, let last = finalDays.last else {
                return "Add one shared final weigh-in in the last 3 days."
            }
            return "Add one shared final weigh-in from \(dateRange(first, last))."
        case .maximumWeightGap:
            if let gap = firstExcessiveWeightGap {
                return "Review the \(gap.days)-day weight gap from \(dateRange(gap.start, gap.end)); gaps must be 10 days or less."
            }
            return "Keep every gap between weigh-in days at 10 days or less."
        }
    }

    func dateRange(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(date: .abbreviated, time: .omitted))–\(end.formatted(date: .abbreviated, time: .omitted))"
    }
}

private func checkDataReasonText(_ reason: AdaptiveCalorieCheckDataReason) -> String {
    switch reason {
    case .invalidDate: "A calendar date could not be evaluated safely."
    case .invalidFoodCalories: "One or more completed days contain an invalid calorie total."
    case .duplicateFoodDay: "More than one completion record exists for a civil day."
    case .invalidTrend: "Weight measurements do not support a finite coincident trend interval."
    case .unsupportedMaintenance: "Observed maintenance fell outside the supported 800–6,000 kcal estimate range."
    case .estimatesDisagree: "The 28-, 35-, and 42-day estimates do not agree closely enough."
    case .unsupportedCandidate: "Resulting calorie goal would be outside the supported 1,000–5,000 kcal range."
    case .discrepancyTooLarge: "Difference exceeds 400 kcal/day; review logs and calculated setup instead of stepping toward it."
    }
}

private func pauseText(_ reason: AdaptiveCaloriePauseReason) -> String {
    switch reason {
    case .manualSource: "Manual goals are paused. Review calculated setup to use check-ins."
    case .unknownSource: "Unknown source is paused to preserve this goal safely."
    case .missingCalculatedBasis: "Saved calculated basis is missing, so check-ins are paused."
    case .unsupportedScope: "Current scope is not supported for a check-in proposal."
    case .targetReached: "Target appears reached. Review plan instead of changing goal automatically."
    case .cumulativeStepCap: "Recent accepted steps reached current 28-day cap. Check-ins pause until enough time passes."
    }
}

private func signedWeightTrend(_ kilogramsPerWeek: Double) -> String {
    guard kilogramsPerWeek.isFinite else { return "unavailable" }
    let sign = kilogramsPerWeek > 0 ? "+" : kilogramsPerWeek < 0 ? "−" : ""
    return "\(sign)\(abs(kilogramsPerWeek).formatted(.number.precision(.fractionLength(2)))) kg/week"
}

private func signedCalories(_ calories: Int) -> String {
    let sign = calories >= 0 ? "+" : "−"
    return "\(sign)\(abs(calories).formatted()) kcal"
}

private extension AdaptiveWindowEstimateRecord {
    init(_ estimate: AdaptiveCalorieWindowEstimate) {
        self.init(
            nominalDays: estimate.nominalDays,
            trendStart: estimate.trendStart,
            trendEnd: estimate.trendEnd,
            meanLoggedCalories: estimate.meanLoggedCalories,
            kilogramsPerDay: estimate.kilogramsPerDay,
            observedMaintenanceCalories: estimate.observedMaintenanceCalories
        )
    }
}

#if DEBUG
#Preview("Adaptive proposal") {
    let container = PreviewData.makeContainer(state: .adaptiveProposal)
    let profile = try! container.mainContext.fetch(FetchDescriptor<UserProfile>()).first!
    NavigationStack {
        AdaptivePlanView(profile: profile, onReviewCalculatedSetup: {})
    }
    .previewPlanEvidenceContainer(container)
}

#Preview("Adaptive collecting AX3") {
    let container = PreviewData.makeContainer(state: .adaptiveCollecting)
    let profile = try! container.mainContext.fetch(FetchDescriptor<UserProfile>()).first!
    NavigationStack {
        AdaptivePlanView(profile: profile, onReviewCalculatedSetup: {})
    }
    .previewPlanEvidenceContainer(container)
    .dynamicTypeSize(.accessibility3)
    .preferredColorScheme(.dark)
}
#endif
