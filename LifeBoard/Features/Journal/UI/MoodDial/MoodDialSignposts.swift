//
//  MoodDialSignposts.swift
//  MoodDialKit
//
//  Package-local mirror of the host apps' performance signposts so dial
//  instrumentation keeps its event names without an app dependency.
//

import Foundation
import os

enum MoodDialSignposts {
    struct Token {
        #if DEBUG || PROFILE_SIGNPOSTS
        let name: StaticString
        let id: OSSignpostID
        #endif
    }

    #if DEBUG || PROFILE_SIGNPOSTS
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "MoodDialKit",
        category: .pointsOfInterest
    )
    #endif

    static func event(_ name: StaticString) {
        #if DEBUG || PROFILE_SIGNPOSTS
        os_signpost(.event, log: log, name: name)
        #endif
    }

    static func begin(_ name: StaticString) -> Token {
        #if DEBUG || PROFILE_SIGNPOSTS
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        return Token(name: name, id: id)
        #else
        return Token()
        #endif
    }

    static func end(_ token: Token) {
        #if DEBUG || PROFILE_SIGNPOSTS
        os_signpost(.end, log: log, name: token.name, signpostID: token.id)
        #endif
    }
}
