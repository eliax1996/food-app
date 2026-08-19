import SwiftData

@Model
final class AppMigrationState {
    @Attribute(.unique) private(set) var key: String = "application"
    private(set) var plateProvenanceVersion: Int = 0

    init(key: String = "application", plateProvenanceVersion: Int = 0) {
        self.key = key
        self.plateProvenanceVersion = plateProvenanceVersion
    }

    func replacePlateProvenanceVersion(
        _ version: Int,
        access: PlanEvidenceMutationAccess
    ) {
        plateProvenanceVersion = version
    }
}
