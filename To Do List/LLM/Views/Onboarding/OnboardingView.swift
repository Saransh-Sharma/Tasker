//
//  OnboardingView.swift
//
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))

                    VStack(spacing: 4) {
                        Text("I am Eva !")
                            .font(.tasker(.title1))
                            .fontWeight(.semibold)
                        Text("your personal AI assistant")
                            .font(.tasker(.callout))
                            .fontWeight(.semibold).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
//                        Text("chat about your tasks, projects, and more with me")
//                            .foregroundStyle(.secondary)
//                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                                
                VStack(alignment: .leading, spacing: 16) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("fast")
                                .font(.tasker(.headline))
                            Text("optimized for apple silicon")
                                .font(.tasker(.callout))
                                .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                        }
                    } icon: {
                        Image(systemName: "message")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                            .padding(.trailing, 8)
                    }
                    
                    Label {
                        VStack(alignment: .leading) {
                            Text("offline")
                                .font(.tasker(.headline))
                            Text("runs locally on your device")
                                .font(.tasker(.callout))
                                .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                        }
                    } icon: {
                        Image(systemName: "checkmark.shield")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                            .padding(.trailing, 8)
                    }

                    // Insightful
                    Label {
                        VStack(alignment: .leading) {
                            Text("insightful")
                                .font(.tasker(.headline))
                            Text("smart productivity suggestions")
                                .font(.tasker(.callout))
                                .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                        }
                    } icon: {
                        Image(systemName: "lightbulb")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                            .padding(.trailing, 8)
                    }

                    // Context-Aware
                    Label {
                        VStack(alignment: .leading) {
                            Text("context-aware")
                                .font(.tasker(.headline))
                            Text("adapts to your current projects")
                                .font(.tasker(.callout))
                                .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                        }
                    } icon: {
                        Image(systemName: "brain.head.profile")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                            .padding(.trailing, 8)
                    }

                    // Battery-Light
                    Label {
                        VStack(alignment: .leading) {
                            Text("battery-light")
                                .font(.tasker(.headline))
                            Text("tiny power footprint")
                                .font(.tasker(.callout))
                                .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                        }
                    } icon: {
                        Image(systemName: "battery.100.bolt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                            .padding(.trailing, 8)
                    }

                    // Smart Recap
                    Label {
                        VStack(alignment: .leading) {
                            Text("smart recap")
                                .font(.tasker(.headline))
                            Text("daily / weekly digests")
                                .font(.tasker(.callout))
                                .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                        }
                    } icon: {
                        Image(systemName: "list.bullet.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.textSecondary))
                            .padding(.trailing, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                
                Spacer()
                
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("get started")
                        #if os(iOS) || os(visionOS)
                        .font(.tasker(.headline))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        #endif
                        #if os(iOS)
                        .foregroundStyle(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.accentOnPrimary))
                        #endif
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("welcome")
            .toolbar(.hidden)
        }
        .tint(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.accentPrimary))
        #if os(macOS)
        .frame(width: 420, height: 520)
        #endif
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
