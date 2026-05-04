//
//  CreditsView.swift
//
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        Form {
            Section(header: Text("open source")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker(.textTertiary))
            ) {
                Link(destination: URL(string: "https://github.com/ml-explore/mlx-swift")!) {
                    HStack {
                        Text("MLX Swift")
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker(.textPrimary))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker(.textTertiary))
                    }
                }

                Link(destination: URL(string: "https://mainfra.me")!) {
                    HStack {
                        Text("Mainframe")
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker(.textPrimary))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker(.textTertiary))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("credits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    CreditsView()
}
