import SwiftUI

struct GroupsView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var groups: [GroupDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateGroup = false

    var body: some View {
        PaisaScreen {
            PaisaPanel(tint: PaisaTheme.sky.opacity(0.46)) {
                VStack(alignment: .leading, spacing: 14) {
                    PaisaSectionHeader("Groups", subtitle: "Your shared money spaces", systemImage: "person.3.fill")

                    HStack(spacing: 10) {
                        PaisaPill(title: "\(groups.count) active", tint: PaisaTheme.plum)
                        PaisaPill(title: "\(groups.reduce(0) { $0 + $1.memberCount }) people", tint: PaisaTheme.teal)
                    }

                    PaisaPrimaryButton("Create group", systemImage: "plus.circle.fill") {
                        showingCreateGroup = true
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                PaisaSectionHeader("Browse", subtitle: "Current groups", systemImage: "square.grid.2x2.fill")

                if groups.isEmpty && !isLoading {
                    PaisaEmptyState(
                        title: "No groups yet",
                        subtitle: "No group activity yet.",
                        systemImage: "person.3.sequence.fill"
                    )
                } else {
                    VStack(spacing: 12) {
                        ForEach(groups) { group in
                            NavigationLink(value: group.id) {
                                PaisaPanel(tint: tint(for: group.category), interactive: true) {
                                    GroupRow(group: group)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if isLoading {
                PaisaPanel(tint: PaisaTheme.mint.opacity(0.4)) {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Refreshing groups")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Groups")
        .navigationDestination(for: String.self) { groupId in
            GroupDetailView(groupId: groupId)
        }
        .toolbar {
            Button {
                showingCreateGroup = true
            } label: {
                Label("New group", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Create group")
        }
        .task { await load() }
        .refreshable { await load() }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showingCreateGroup) {
            CreateGroupView {
                Task { await load() }
            }
        }
    }

    private func tint(for category: String) -> Color {
        switch category.uppercased() {
        case "TRIP":
            PaisaTheme.sky.opacity(0.42)
        case "HOME":
            PaisaTheme.mint.opacity(0.42)
        case "WORK":
            PaisaTheme.blush.opacity(0.42)
        case "COUPLE":
            PaisaTheme.sun.opacity(0.20)
        default:
            PaisaTheme.sky.opacity(0.36)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: GroupsResponse = try await authStore.apiClient.get("/api/mobile/groups")
            groups = response.groups
        } catch APIError.unauthorized {
            authStore.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct GroupRow: View {
    let group: GroupDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PaisaIconBadge(systemImage: symbol(for: group.category), tint: tone(for: group.category))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(group.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PaisaTheme.ink)
                    Spacer()
                    PaisaPill(title: group.currency, tint: PaisaTheme.plum)
                }

                Text(group.description?.isEmpty == false ? group.description ?? "" : "No description yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    PaisaPill(title: "\(group.expenseCount) expenses", tint: PaisaTheme.teal)
                    PaisaPill(title: "\(group.memberCount) members", tint: PaisaTheme.leaf)
                }
            }
        }
    }

    private func symbol(for category: String) -> String {
        switch category.uppercased() {
        case "TRIP": "airplane.circle.fill"
        case "HOME": "house.circle.fill"
        case "WORK": "briefcase.circle.fill"
        case "COUPLE": "heart.circle.fill"
        default: "sparkles"
        }
    }

    private func tone(for category: String) -> Color {
        switch category.uppercased() {
        case "TRIP": PaisaTheme.plum
        case "HOME": PaisaTheme.leaf
        case "WORK": PaisaTheme.teal
        case "COUPLE": PaisaTheme.coral
        default: PaisaTheme.sun
        }
    }
}

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    @State private var name = ""
    @State private var description = ""
    @State private var currency = "INR"
    @State private var category = "OTHER"
    @State private var errorMessage: String?
    @State private var isSaving = false
    let onSaved: () -> Void

    private let categories = ["HOME", "TRIP", "COUPLE", "WORK", "OTHER"]
    private let currencies = ["INR", "USD", "EUR", "GBP", "CAD", "AUD"]

    var body: some View {
        NavigationStack {
            PaisaScreen {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.46)) {
                    PaisaSectionHeader("New group", subtitle: "A clean start for shared spending", systemImage: "person.3.badge.plus")
                }

                PaisaPanel(tint: PaisaTheme.mint.opacity(0.42)) {
                    VStack(alignment: .leading, spacing: 16) {
                        PaisaFieldLabel("Name") {
                            TextField("Group name", text: $name)
                                .paisaTextField()
                        }

                        PaisaFieldLabel("Description") {
                            TextField("Optional description", text: $description, axis: .vertical)
                                .lineLimit(2...4)
                                .paisaTextField()
                        }

                        PaisaFieldLabel("Currency") {
                            Picker("Currency", selection: $currency) {
                                ForEach(currencies, id: \.self, content: Text.init)
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .paisaTextField()
                        }

                        PaisaFieldLabel("Category") {
                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.self, content: Text.init)
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .paisaTextField()
                        }
                    }
                }

                if let errorMessage {
                    PaisaPanel(tint: PaisaTheme.blush.opacity(0.52)) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(PaisaTheme.coral)
                    }
                }

                PaisaPrimaryButton(
                    "Create group",
                    systemImage: "checkmark.circle.fill",
                    isLoading: isSaving,
                    isDisabled: name.isEmpty || isSaving
                ) {
                    Task { await save() }
                }
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let body = CreateGroupRequest(
                name: name,
                description: description.isEmpty ? nil : description,
                currency: currency,
                category: category
            )
            let _: GroupResponse = try await authStore.apiClient.post("/api/mobile/groups", body: body)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
