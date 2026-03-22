import SwiftUI

struct SettingsView: View {
    private var todoColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }
    private let projectManagementDestination: AnyView

    @Environment(\.presentationMode) var presentationMode // To dismiss the view later
    @State private var showingVersionAlert = false // State for controlling the alert

    // Helper to get app version and build number
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    /// Initializes a new instance.
    init(
        projectManagementDestination: AnyView = AnyView(
            Text("Project management requires injected dependencies.")
                .foregroundColor(.secondary)
                .padding()
        )
    ) {
        self.projectManagementDestination = projectManagementDestination
    }

    var body: some View {
        NavigationStack {
            Form { // Using Form for grouped table view style
                Section(header: Text("Projects").foregroundColor(Color(uiColor: todoColors.accentPrimary))) {
                    NavigationLink(destination: projectManagementDestination) {
                        Text("Manage Projects") // Standard text color
                    }
                }

                Section(header: Text("Appearance").foregroundColor(Color(uiColor: todoColors.accentPrimary))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("System appearance", systemImage: "circle.lefthalf.filled")
                            .foregroundColor(Color(uiColor: todoColors.textPrimary))

                        Text("To Do List follows your iPhone or iPad light and dark appearance automatically.")
                            .font(.footnote)
                            .foregroundColor(Color(uiColor: todoColors.textSecondary))
                    }
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
    }
}
