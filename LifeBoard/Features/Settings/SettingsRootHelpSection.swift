import SwiftUI
#if os(iOS)
import UIKit
#endif

extension SettingsRootView {
    var appVersionText: String {
        "v\(viewModel.appVersion) (\(viewModel.buildNumber))"
    }

    func helpSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        SettingsSectionView(
            title: "Help & about",
            subtitle: "",
            topPadding: sectionTopPadding,
            includeHorizontalPadding: includeHorizontalPadding
        ) {
            VStack(spacing: spacing.cardStackVertical) {
                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "arrow.clockwise.circle.fill",
                            title: "Replay setup",
                            subtitle: "",
                            accessibilityIdentifier: "settings.onboarding.restartButton"
                        ),
                        action: viewModel.restartOnboarding
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex)

                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "doc.text.fill",
                            title: "Acknowledgements",
                            subtitle: "",
                            tone: .neutral,
                            accessibilityIdentifier: "settings.acknowledgements.row"
                        ),
                        action: { navigate(.notices) }
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                SettingsCard {
                    VStack(spacing: 0) {
                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "questionmark.circle.fill",
                                title: "Contact support",
                                subtitle: "",
                                tone: .neutral,
                                accessibilityIdentifier: "settings.support.row"
                            ),
                            action: { openURL(LifeBoardLegalLinks.support) }
                        )
                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "hand.raised.fill",
                                title: "Privacy policy",
                                subtitle: "",
                                tone: .neutral,
                                accessibilityIdentifier: "settings.privacyPolicy.row"
                            ),
                            action: { openURL(LifeBoardLegalLinks.privacyPolicy) }
                        )
                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "doc.plaintext.fill",
                                title: "Terms of use",
                                subtitle: "",
                                tone: .neutral,
                                accessibilityIdentifier: "settings.terms.row"
                            ),
                            action: { openURL(LifeBoardLegalLinks.termsOfUse) }
                        )
                    }
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                SettingsCard {
                    // A fact with a Copy button, not a row that looks like it
                    // opens something and then silently copies.
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        HStack(alignment: .top, spacing: SwiftUITokens.spacing.s12) {
                            SettingsRowIcon(iconName: "info.circle.fill", tone: .neutral)
                            VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s4) {
                                Text("App version")
                                    .font(.lifeboard(.bodyStrong))
                                    .foregroundStyle(Color.lifeboard(.textPrimary))
                                Text(appVersionText)
                                    .font(.lifeboard(.callout))
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings.appVersionRow")

                        Spacer(minLength: SwiftUITokens.spacing.s8)

                        #if os(iOS)
                        Button(copiedVersion ? "Copied" : "Copy") {
                            UIPasteboard.general.string = appVersionText
                            Haptic.pick.play()
                            copiedVersion = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(1.4))
                                copiedVersion = false
                            }
                        }
                        .buttonStyle(.lifeBoardChip)
                        .lifeBoardMotion(.localState, value: copiedVersion)
                        .accessibilityLabel(copiedVersion ? "Copied" : "Copy app version")
                        .accessibilityIdentifier("settings.appVersionRow.copy")
                        #endif
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)

                #if DEBUG
                SettingsCard {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "doc.on.clipboard.fill",
                            title: "Copy calendar diagnostics",
                            subtitle: "",
                            tone: .neutral,
                            accessibilityIdentifier: "settings.calendarDiagnostics.copyButton"
                        ),
                        action: viewModel.copyCalendarDiagnostics
                    )
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)
                #endif
            }
        }
    }
}

/// Where the in-app legal and support rows go. App Review requires a privacy
/// policy reachable inside the app; the terms are Apple's standard EULA.
enum LifeBoardLegalLinks {
    static let support = URL(string: "https://getlifeboard.app/support/")!
    static let privacyPolicy = URL(string: "https://getlifeboard.app/privacy/")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
