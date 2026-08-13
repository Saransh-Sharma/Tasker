//
//  TimelinePreferenceKeys.swift
//  LifeBoard
//
//  Move-only timeline decomposition.
//

import SwiftUI

struct TimelineHeaderHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimelineCalendarCardHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct TimelineBackdropWeekHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HeightPreferenceReader<Key: PreferenceKey>: ViewModifier where Key.Value == CGFloat {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear.preference(key: Key.self, value: proxy.size.height)
            }
        }
    }
}

extension View {
    func reportHeight<Key: PreferenceKey>(to key: Key.Type) -> some View where Key.Value == CGFloat {
        modifier(HeightPreferenceReader<Key>())
    }
}


