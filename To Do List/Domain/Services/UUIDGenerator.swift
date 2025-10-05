//
//  UUIDGenerator.swift
//  Tasker
//
//  Service for generating UUIDs with deterministic support for migrations
//

import Foundation
import CommonCrypto

/// Protocol for UUID generation
public protocol UUIDGeneratorProtocol {
    /// Generate a new random UUID
    func generate() -> UUID

    /// Generate a deterministic UUID from a string (for migration purposes)
    func generateDeterministic(from string: String) -> UUID
}

/// Default implementation of UUID generator
public final class UUIDGenerator: UUIDGeneratorProtocol {

    public init() {}

    /// Generate a new random UUID
    public func generate() -> UUID {
        return UUID()
    }

    /// Generate a deterministic UUID from a string using MD5 hashing
    /// This ensures the same string always produces the same UUID
    /// Useful for migrating existing data that lacks UUIDs
    public func generateDeterministic(from string: String) -> UUID {
        let hash = md5(string: string)
        return UUID(uuid: hash)
    }

    // MARK: - Private Helpers

    /// Generate MD5 hash from string and convert to UUID bytes
    private func md5(string: String) -> uuid_t {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(data.count), &digest)
        }

        return (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        )
    }
}
