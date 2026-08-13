import LifeBoardContracts
import LifeBoardDomain
//
//  EncryptionService.swift
//  JournalSecurityKit
//
//  AES-256-GCM encryption for local backup files.
//  Uses CryptoKit (built-in, no external dependencies).
//

import Foundation
import CryptoKit

public struct EncryptionService {

    public enum EncryptionError: LocalizedError {
        case invalidData
        case invalidPassword
        case decryptionFailed
        case invalidFileFormat

        public var errorDescription: String? {
            switch self {
            case .invalidData: return "Data is invalid or corrupted."
            case .invalidPassword: return "Incorrect password."
            case .decryptionFailed: return "Failed to decrypt. Check your password."
            case .invalidFileFormat: return "This file is not a valid encrypted journal backup."
            }
        }
    }

    // Current file format:
    // [4-byte magic "DVX2"][4-byte PBKDF2 iteration count][32-byte salt]
    // [12-byte nonce][ciphertext][16-byte tag]
    //
    // DVX1 used HKDF directly on a password. Decryption remains supported so
    // existing user backups are never stranded, while every new archive uses
    // the deliberately expensive, versioned password derivation below.
    private static let currentMagic: [UInt8] = [0x44, 0x56, 0x58, 0x32] // "DVX2"
    private static let legacyMagic: [UInt8] = [0x44, 0x56, 0x58, 0x31] // "DVX1"
    private static let saltSize = 32
    private static let currentPBKDF2Iterations: UInt32 = 100_000
    private static let minimumAcceptedPBKDF2Iterations: UInt32 = 10_000
    private static let maximumAcceptedPBKDF2Iterations: UInt32 = 2_000_000

    /// Encrypt data with a password using AES-256-GCM
    public static func encrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else { throw EncryptionError.invalidPassword }

        let salt = generateSalt()
        let key = derivePBKDF2Key(
            from: password,
            salt: salt,
            iterations: currentPBKDF2Iterations
        )
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.invalidData
        }

        // Build file: magic + KDF parameters + salt + combined payload.
        var output = Data(currentMagic)
        output.append(bigEndianBytes(currentPBKDF2Iterations))
        output.append(salt)
        output.append(combined)
        return output
    }

    /// Decrypt data with a password
    public static func decrypt(data: Data, password: String) throws -> Data {
        guard !password.isEmpty else { throw EncryptionError.invalidPassword }

        let magicSize = currentMagic.count
        let minimumLegacySize = magicSize + saltSize + 12 + 16

        guard data.count >= minimumLegacySize else {
            throw EncryptionError.invalidFileFormat
        }

        let fileMagic = [UInt8](data.prefix(magicSize))
        if fileMagic == currentMagic {
            return try decryptCurrent(data, password: password)
        }
        if fileMagic == legacyMagic {
            return try decryptLegacy(data, password: password)
        }
        throw EncryptionError.invalidFileFormat
    }

    // MARK: - Versioned decoding

    private static func decryptCurrent(_ data: Data, password: String) throws -> Data {
        let headerSize = currentMagic.count + MemoryLayout<UInt32>.size
        let minimumSize = headerSize + saltSize + 12 + 16
        guard data.count >= minimumSize else {
            throw EncryptionError.invalidFileFormat
        }

        let iterationData = data[currentMagic.count..<headerSize]
        let iterations = iterationData.reduce(UInt32.zero) { partial, byte in
            (partial << 8) | UInt32(byte)
        }
        guard (minimumAcceptedPBKDF2Iterations...maximumAcceptedPBKDF2Iterations).contains(iterations) else {
            throw EncryptionError.invalidFileFormat
        }
        let saltRange = headerSize..<(headerSize + saltSize)
        let salt = Data(data[saltRange])
        let combined = data[(headerSize + saltSize)...]
        let key = derivePBKDF2Key(from: password, salt: salt, iterations: iterations)
        return try open(combined: combined, using: key)
    }

    private static func decryptLegacy(_ data: Data, password: String) throws -> Data {
        let saltStart = legacyMagic.count
        let saltEnd = saltStart + saltSize
        guard data.count >= saltEnd + 12 + 16 else {
            throw EncryptionError.invalidFileFormat
        }
        let salt = Data(data[saltStart..<saltEnd])
        let combined = data[saltEnd...]
        let key = deriveLegacyKey(from: password, salt: salt)
        return try open(combined: combined, using: key)
    }

    private static func open(combined: Data.SubSequence, using key: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // MARK: - Helpers

    private static func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func deriveLegacyKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            outputByteCount: 32
        )
        return derived
    }

    /// RFC 8018 PBKDF2-HMAC-SHA256. Keeping the implementation here avoids a
    /// new dependency in the small shared security target and makes every KDF
    /// parameter explicit in the archive header.
    private static func derivePBKDF2Key(
        from password: String,
        salt: Data,
        iterations: UInt32,
        outputByteCount: Int = 32
    ) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(password.utf8))
        let hashLength = SHA256.Digest.byteCount
        let blockCount = Int(ceil(Double(outputByteCount) / Double(hashLength)))
        var derived = Data()
        derived.reserveCapacity(blockCount * hashLength)

        for blockIndex in 1...blockCount {
            var firstInput = salt
            firstInput.append(bigEndianBytes(UInt32(blockIndex)))
            var previous = Data(HMAC<SHA256>.authenticationCode(for: firstInput, using: passwordKey))
            var block = previous

            if iterations > 1 {
                for _ in 2...iterations {
                    previous = Data(HMAC<SHA256>.authenticationCode(for: previous, using: passwordKey))
                    for index in block.indices {
                        block[index] ^= previous[index]
                    }
                }
            }
            derived.append(block)
        }

        return SymmetricKey(data: derived.prefix(outputByteCount))
    }

    private static func bigEndianBytes(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }
}
