import SwiftUI

/// One disclosure for every activation surface; defaults are choices, not consent.
struct EvaCloudDisclosure: View {
    let grants: [(grant: EvaConsentPolicy.Grant, title: String, isOn: Binding<Bool>)]
    var isWorking = false
    var identifierPrefix = "eva.disclosure"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What EVA can use").lifeboardFont(.bodyStrong)
            Text("Your questions, life areas, tasks, and plans pass through LifeBoard’s Cloudflare service to OpenAI to prepare an answer.")
                .lifeboardFont(.support)
            Text("Optional context is on by default. Turn off anything you don’t want EVA to use.")
                .lifeboardFont(.caption1)
            ForEach(grants, id: \.grant) { entry in
                Toggle(entry.title, isOn: entry.isOn)
                    .toggleStyle(.lifeBoardClay)
                    .disabled(isWorking)
                    .accessibilityIdentifier("\(identifierPrefix).grant.\(entry.grant.rawValue)")
            }
            Text("Enabled categories may be included in future EVA requests when available, including Health data you connect later. Enabling EVA does not grant Apple Health access or enable writing to Health.")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            DisclosureGroup("How it works") {
                Text("LifeBoard sends your question and allowed context to its cloud service, which requests an answer from OpenAI. You can change context choices in EVA settings before your next request.")
                    .lifeboardFont(.caption1)
                    .padding(.top, 8)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
