import SwiftUI

struct SlashCommandPickerView: View {
    @Binding var query: String
    let recentCommands: [SlashCommandDescriptor]
    let popularCommands: [SlashCommandDescriptor]
    let allCommands: [SlashCommandDescriptor]
    var onSelect: (SlashCommandDescriptor) -> Void

    @FocusState private var isSearchFocused: Bool

    private var showFilteredOnly: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var allSectionCommands: [SlashCommandDescriptor] {
        guard showFilteredOnly == false else { return allCommands }
        let alreadyShown = Set((recentCommands + popularCommands).map(\.id))
        let deduped = allCommands.filter { alreadyShown.contains($0.id) == false }
        return deduped.isEmpty ? allCommands : deduped
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                TextField("Search commands", text: $query)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .padding(.vertical, LifeBoardTheme.Spacing.sm)
                    .background(Color.lifeboard(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                            .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                    )
                    .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                    .accessibilityIdentifier("chat.command_picker.search")

                ScrollView {
                    VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.md) {
                        if showFilteredOnly, allCommands.isEmpty {
                            Text("No commands found")
                                .font(.lifeboard(.caption1))
                                .foregroundColor(Color.lifeboard(.textTertiary))
                                .padding(.top, LifeBoardTheme.Spacing.md)
                                .accessibilityIdentifier("chat.command_picker.empty")
                        } else if showFilteredOnly {
                            commandSection(title: "All Commands", commands: allCommands)
                        } else {
                            if recentCommands.isEmpty == false {
                                commandSection(title: "Recent", commands: recentCommands)
                            }
                            commandSection(title: "Popular", commands: popularCommands)
                            commandSection(title: "All Commands", commands: allSectionCommands)
                        }
                    }
                    .padding(.horizontal, LifeBoardTheme.Spacing.lg)
                    .padding(.bottom, LifeBoardTheme.Spacing.xl)
                }
            }
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    @ViewBuilder
    private func commandSection(title: String, commands: [SlashCommandDescriptor]) -> some View {
        if commands.isEmpty == false {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
                Text(title)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard(.textTertiary))

                VStack(spacing: LifeBoardTheme.Spacing.xs) {
                    ForEach(commands, id: \.id) { descriptor in
                        Button {
                            onSelect(descriptor)
                        } label: {
                            SlashCommandRowView(descriptor: descriptor, query: query)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(descriptor.command), \(descriptor.shortDescription)")
                        .accessibilityIdentifier("chat.command_picker.row.\(descriptor.id.rawValue)")
                    }
                }
            }
        }
    }
}

private struct SlashCommandRowView: View {
    let descriptor: SlashCommandDescriptor
    let query: String

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            Image(systemName: descriptor.id.icon)
                .font(.lifeboard(.callout))
                .foregroundColor(Color.lifeboard(.accentPrimary))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                highlightedCommand
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard(.textPrimary))
                Text(descriptor.shortDescription)
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard(.textTertiary))
            }

            Spacer(minLength: LifeBoardTheme.Spacing.sm)

            Text(descriptor.example)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard(.textQuaternary))
                .lineLimit(1)
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.md)
        .padding(.vertical, LifeBoardTheme.Spacing.sm)
        .frame(minHeight: 44)
        .background(Color.lifeboard(.surfaceSecondary))
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
        )
    }

    private var highlightedCommand: Text {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedQuery.isEmpty == false,
              let range = descriptor.command.lowercased().range(of: normalizedQuery) else {
            return Text(descriptor.command)
        }

        let lowerBound = descriptor.command.distance(from: descriptor.command.startIndex, to: range.lowerBound)
        let upperBound = descriptor.command.distance(from: descriptor.command.startIndex, to: range.upperBound)

        let prefix = String(descriptor.command.prefix(lowerBound))
        let match = String(descriptor.command.dropFirst(lowerBound).prefix(upperBound - lowerBound))
        let suffix = String(descriptor.command.dropFirst(upperBound))

        return Text(prefix) + Text(match).bold() + Text(suffix)
    }
}
