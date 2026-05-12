//
//  CreditsView.swift
//
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        Form {
            Section(header: Text("open source")
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard(.textTertiary))
            ) {
                Link(destination: URL(string: "https://github.com/ml-explore/mlx-swift")!) {
                    HStack {
                        Text("MLX Swift")
                            .font(.lifeboard(.body))
                            .foregroundColor(Color.lifeboard(.textPrimary))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard(.textTertiary))
                    }
                }

                Link(destination: URL(string: "https://mainfra.me")!) {
                    HStack {
                        Text("Mainframe")
                            .font(.lifeboard(.body))
                            .foregroundColor(Color.lifeboard(.textPrimary))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard(.textTertiary))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("credits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    CreditsView()
}
