//
//  AppearanceSettingsView.swift
//
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appManager: AppManager

    var body: some View {
        Form {
            Section("Theme") {
                Text("LLM appearance now follows the shared app design tokens.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(.secondary)
            }

            Section("Typography") {
                Text("Typography is managed globally with Dynamic Type.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("appearance")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    AppearanceSettingsView()
}
