import Foundation
import SwiftData

@Model
final class HistoricalPlateDeletionOperation {
    @Attribute(.unique) private(set) var operationID: UUID = UUID()
    private(set) var plateStableID: UUID = UUID()
    private(set) var deletedAt: Date = Date.now

    init(operationID: UUID, plateStableID: UUID, deletedAt: Date) {
        self.operationID = operationID
        self.plateStableID = plateStableID
        self.deletedAt = deletedAt
    }
}
