import Foundation
import os

nonisolated enum AppLogCategory: String, Sendable {
    case persistence
    case userAction = "user_action"
    case integrations
    case reminders
    case scanner
    case bulkFood = "bulk_food"
}

nonisolated enum AppLogErrorCategory: String, Equatable, Sendable {
    case cancelled
    case conflict
    case corruptData = "corrupt_data"
    case invalidInput = "invalid_input"
    case networkOffline = "network_offline"
    case networkTimeout = "network_timeout"
    case notFound = "not_found"
    case permission
    case rateLimited = "rate_limited"
    case storage
    case unavailable
    case other
}

nonisolated struct AppLogOperation: Equatable, Sendable {
    let id: UUID
    let name: String
    let category: AppLogCategory
    let source: String
    let parentID: UUID?
}

enum AppLogger {
    static let persistence = Logger(
        subsystem: "ch.elia.count-calories",
        category: AppLogCategory.persistence.rawValue
    )

    private static let userAction = Logger(
        subsystem: "ch.elia.count-calories",
        category: AppLogCategory.userAction.rawValue
    )
    private static let integrations = Logger(
        subsystem: "ch.elia.count-calories",
        category: AppLogCategory.integrations.rawValue
    )
    private static let reminders = Logger(
        subsystem: "ch.elia.count-calories",
        category: AppLogCategory.reminders.rawValue
    )
    private static let scanner = Logger(
        subsystem: "ch.elia.count-calories",
        category: AppLogCategory.scanner.rawValue
    )
    private static let bulkFood = Logger(
        subsystem: "ch.elia.count-calories",
        category: AppLogCategory.bulkFood.rawValue
    )

    /// Starts one privacy-safe operational span. `name` and `source` must be fixed
    /// taxonomy values, never user-entered content or persisted health values.
    @discardableResult
    static func begin(
        _ name: String,
        category: AppLogCategory,
        source: String,
        count: Int? = nil,
        id: UUID = UUID(),
        parentID: UUID? = nil
    ) -> AppLogOperation {
        let operation = AppLogOperation(
            id: id,
            name: name,
            category: category,
            source: source,
            parentID: parentID
        )
        logger(for: category).notice(
            "event=operation_start operation=\(name, privacy: .public) operation_id=\(operation.id.uuidString, privacy: .public) parent_id=\(parentID?.uuidString ?? "none", privacy: .public) source=\(source, privacy: .public) count=\(count ?? -1, privacy: .public)"
        )
        return operation
    }

    static func succeed(_ operation: AppLogOperation, count: Int? = nil) {
        logger(for: operation.category).notice(
            "event=operation_success operation=\(operation.name, privacy: .public) operation_id=\(operation.id.uuidString, privacy: .public) parent_id=\(operation.parentID?.uuidString ?? "none", privacy: .public) source=\(operation.source, privacy: .public) count=\(count ?? -1, privacy: .public)"
        )
    }

    static func noop(_ operation: AppLogOperation, reason: String) {
        logger(for: operation.category).info(
            "event=operation_noop operation=\(operation.name, privacy: .public) operation_id=\(operation.id.uuidString, privacy: .public) parent_id=\(operation.parentID?.uuidString ?? "none", privacy: .public) source=\(operation.source, privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    static func cancel(_ operation: AppLogOperation, reason: String = "cancelled") {
        logger(for: operation.category).info(
            "event=operation_cancelled operation=\(operation.name, privacy: .public) operation_id=\(operation.id.uuidString, privacy: .public) parent_id=\(operation.parentID?.uuidString ?? "none", privacy: .public) source=\(operation.source, privacy: .public) reason=\(reason, privacy: .public)"
        )
    }

    static func partial(_ operation: AppLogOperation, failedComponent: String) {
        logger(for: operation.category).error(
            "event=operation_partial operation=\(operation.name, privacy: .public) operation_id=\(operation.id.uuidString, privacy: .public) parent_id=\(operation.parentID?.uuidString ?? "none", privacy: .public) source=\(operation.source, privacy: .public) failed_component=\(failedComponent, privacy: .public)"
        )
    }

    static func fail(
        _ operation: AppLogOperation,
        error: Error,
        rollback: String = "not_needed"
    ) {
        let category = errorCategory(for: error)
        logger(for: operation.category).error(
            "event=operation_failure operation=\(operation.name, privacy: .public) operation_id=\(operation.id.uuidString, privacy: .public) parent_id=\(operation.parentID?.uuidString ?? "none", privacy: .public) source=\(operation.source, privacy: .public) error_category=\(category.rawValue, privacy: .public) rollback=\(rollback, privacy: .public)"
        )
    }

    nonisolated static func errorCategory(for error: Error) -> AppLogErrorCategory {
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .cannotFindHost, .dnsLookupFailed:
                return .networkOffline
            case .timedOut:
                return .networkTimeout
            case .userAuthenticationRequired, .userCancelledAuthentication:
                return .permission
            default:
                return .other
            }
        }
        if let dictationFailure = error as? MealDictationFailure {
            switch dictationFailure {
            case .permissionDenied:
                return .permission
            case .interrupted:
                return .cancelled
            case .assetsUnavailable, .noInputDevice, .operatingSystem,
                 .resourcesUnavailable, .unsupportedLocale:
                return .unavailable
            case .unknown:
                return .other
            }
        }
        if let persistenceError = error as? BulkFoodPersistenceError {
            return persistenceError == .staleLease ? .conflict : .unavailable
        }
        if error is BulkFoodValidationError { return .invalidInput }
        if let extractionFailure = error as? BulkFoodExtractionFailure {
            switch extractionFailure {
            case .cancelled:
                return .cancelled
            case .emptyInput, .inputTooLong, .invalidOutput:
                return .invalidInput
            case .unavailable, .resourcesUnavailable:
                return .unavailable
            case .contextLimit, .refused, .safetyGuardrail, .unknown:
                return .other
            }
        }
        if let mutationError = error as? PlanEvidenceMutationError {
            switch mutationError {
            case .compareAndSetFailed, .proposalNotCurrent, .revertConflict,
                 .evidenceSignatureChanged, .epochBasisChanged:
                return .conflict
            case .corruptAdaptivePayload, .unsupportedAdaptiveSchema:
                return .corruptData
            case .coordinatorUnavailable, .historicalMutationUnavailable,
                 .missingCalculatedBasis, .missingPendingProposal, .missingProfile:
                return .unavailable
            case .identityCollision, .multipleProfiles, .duplicateCompletion,
                 .duplicateHistoricalEntry:
                return .conflict
            case .invalidBulkBatch, .invalidCalories, .invalidCompletionDay,
                 .invalidHistoricalMutation, .invalidPersonalNutritionTargets,
                 .supportedScopeConfirmationRequired, .unsupportedSource:
                return .invalidInput
            case .calendarOrTimeZoneChanged, .evidenceOverflow, .identityMigrationRequired,
                 .identityVerificationFailed, .proposalExpired, .revisionOverflow,
                 .uncommittedChanges:
                return .conflict
            }
        }
        if error is CocoaError || error is POSIXError || error is DecodingError || error is EncodingError {
            return .storage
        }
        return .other
    }

    private static func logger(for category: AppLogCategory) -> Logger {
        switch category {
        case .persistence: persistence
        case .userAction: userAction
        case .integrations: integrations
        case .reminders: reminders
        case .scanner: scanner
        case .bulkFood: bulkFood
        }
    }
}
