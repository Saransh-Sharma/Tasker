import SwiftUI
import FluentUI

struct SettingsView: View {
    private var todoColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }

    @Environment(\.presentationMode) var presentationMode // To dismiss the view later
    // State to track the current mode, initialized based on system's current style
    @State private var isDarkMode: Bool = UIScreen.main.traitCollection.userInterfaceStyle == .dark
    @State private var showingVersionAlert = false // State for controlling the alert

    // Helper to get app version and build number
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var body: some View {
        NavigationView {
            Form { // Using Form for grouped table view style
                Section(header: Text("Projects").foregroundColor(Color(uiColor: todoColors.accentPrimary))) {
                    NavigationLink(destination: ProjectManagementView()) { // NEW
                        Text("Manage Projects") // Standard text color
                    }
                }

                Section(header: Text("Appearance").foregroundColor(Color(uiColor: todoColors.accentPrimary))) {
                    Button(action: {
                        isDarkMode.toggle()
                        if #available(iOS 13.0, *) {
                            let newStyle: UIUserInterfaceStyle = isDarkMode ? .dark : .light
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                windowScene.windows.forEach { window in
                                    window.overrideUserInterfaceStyle = newStyle
                                }
                            }
                        }
                        // No need for alerts like in the old version for now
                    }) {
                        HStack {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .foregroundColor(Color(uiColor: todoColors.accentPrimary))
                            Text(isDarkMode ? "Light Mode" : "Dark Mode")
                        }
                    }
                    // Standard text color for the button label itself is often fine to indicate interactivity.
                    // If specific text color is needed: .foregroundColor(Color(todoColors.textColor))
                }

                // New section for LLM / AI Assistant settings
                Section(header: Text("AI Assistant").foregroundColor(Color(uiColor: todoColors.accentPrimary))) {
                    NavigationLink(destination: LLMSettingsView(currentThread: .constant(nil))) {
                        Text("LLM Settings")
                    }
                }

                Section(header: Text("About").foregroundColor(Color(uiColor: todoColors.accentPrimary))) {
                    HStack {
                        Text("Version") // Standard text color
                        Spacer()
                        Text(appVersion) // Display version number on the row
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle()) // Make the whole HStack tappable
                    .onTapGesture {
                        showingVersionAlert = true
                    }
                }
            }
            // Attempting to color NavigationBarTitle directly. This might have limitations.
            // For more robust styling, UINavigationBarAppearance in AppDelegate/SceneDelegate is preferred.
            .navigationBarTitle(Text("Settings")
                // .foregroundColor(Color(todoColors.accentPrimary)) // This often doesn't work as expected for nav titles.
                // Let's rely on global appearance or default for now.
                , displayMode: .inline)
            .navigationBarItems(trailing:
                Button(action: {
                    logDebug("Done button tapped") // Keep for debugging if you want
                    self.presentationMode.wrappedValue.dismiss() // Add this line
                }) {
                    Text("Done")
                        .foregroundColor(Color(uiColor: todoColors.accentPrimary))
                }
            )
            .alert(isPresented: $showingVersionAlert) {
                Alert(
                    title: Text("App Version"),
                    message: Text("Version: \(appVersion)\nBuild: \(appBuild)"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        // Update isDarkMode state if the system theme changes from outside
        .onAppear {
            isDarkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            // More complex nav bar styling would go here if using UIHostingController specifics
            // For example, accessing parent UIViewController's navigationItem.
            // However, direct SwiftUI styling is preferred if possible.
        }
        .onChange(of: UIScreen.main.traitCollection.userInterfaceStyle) { _, newStyle in
            isDarkMode = newStyle == .dark
        }
    }
}
