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
                
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
                    
                    VStack(spacing: 4) {
                        Text("I am Eva !\nyour personal AI assistant")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("chat about your tasks, projects, and more with me")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                                
                VStack(alignment: .leading, spacing: 24) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("fast")
                                .font(.headline)
                            Text("optimized for apple silicon")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "message")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    
                    Label {
                        VStack(alignment: .leading) {
                            Text("offline")
                                .font(.headline)
                            Text("runs locally on your device")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.shield")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    
                    // Insightful
                    Label {
                        VStack(alignment: .leading) {
                            Text("insightful")
                                .font(.headline)
                            Text("smart suggestions and task insights")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lightbulb")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    
                    // Context-Aware
                    Label {
                        VStack(alignment: .leading) {
                            Text("context-aware")
                                .font(.headline)
                            Text("adapts to your current projects and tasks")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "brain.head.profile")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    
                    // Battery-Light
                    Label {
                        VStack(alignment: .leading) {
                            Text("battery-light")
                                .font(.headline)
                            Text("tiny power footprint")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "battery.100.bolt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                    
                    // Smart Recap
                    Label {
                        VStack(alignment: .leading) {
                            Text("smart recap")
                                .font(.headline)
                            Text("daily / weekly digests")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "list.bullet.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                
                Spacer()
                
                NavigationLink(destination: OnboardingInstallModelView(showOnboarding: $showOnboarding)) {
                    Text("get started")
                        #if os(iOS) || os(visionOS)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        #endif
                        #if os(iOS)
                        .foregroundStyle(.background)
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
        #if os(macOS)
        .frame(width: 420, height: 520)
        #endif
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
