import Foundation

public final class MaintainOccurrencesUseCase {
    private let occurrenceRepository: OccurrenceRepositoryProtocol
    private let tombstoneRepository: TombstoneRepositoryProtocol

    public init(
        occurrenceRepository: OccurrenceRepositoryProtocol,
        tombstoneRepository: TombstoneRepositoryProtocol
    ) {
        self.occurrenceRepository = occurrenceRepository
        self.tombstoneRepository = tombstoneRepository
    }

    public func execute(completion: @escaping (Result<Void, Error>) -> Void) {
        let now = Date()
        let pastWindow = Calendar.current.date(byAdding: .day, value: -365, to: now) ?? now
        occurrenceRepository.fetchInRange(start: pastWindow, end: now) { result in
            switch result {
            case .success(let occurrences):
                let staleUnresolved = occurrences.filter {
                    guard $0.state == .pending else { return false }
                    guard let age = Calendar.current.dateComponents([.day], from: $0.scheduledAt, to: now).day else { return false }
                    return age > 30
                }

                let resolvedForPurge = occurrences.filter {
                    guard $0.state == .completed || $0.state == .skipped || $0.state == .missed else { return false }
                    guard let age = Calendar.current.dateComponents([.day], from: $0.scheduledAt, to: now).day else { return false }
                    return age > 90
                }

                let group = DispatchGroup()
                var firstError: Error?

                for occurrence in staleUnresolved {
                    let resolution = OccurrenceResolutionDefinition(
                        id: UUID(),
                        occurrenceID: occurrence.id,
                        resolutionType: .missed,
                        resolvedAt: now,
                        actor: "system",
                        reason: "Auto-marked missed after 30 days",
                        createdAt: now
                    )
                    group.enter()
                    self.occurrenceRepository.resolve(resolution) { result in
                        if case .failure(let error) = result {
                            firstError = firstError ?? error
                        }
                        group.leave()
                    }
                }

                for occurrence in resolvedForPurge {
                    let tombstone = TombstoneDefinition(
                        entityType: "Occurrence",
                        entityID: occurrence.id,
                        deletedAt: now,
                        deletedBy: "system",
                        purgeAfter: Calendar.current.date(byAdding: .day, value: 90, to: now) ?? now
                    )
                    group.enter()
                    self.tombstoneRepository.create(tombstone) { result in
                        if case .failure(let error) = result {
                            firstError = firstError ?? error
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let firstError {
                        completion(.failure(firstError))
                    } else {
                        completion(.success(()))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
