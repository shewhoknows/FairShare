import SwiftUI

struct GroupsView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var groups: [GroupDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateGroup = false

    var body: some View {
        List {
            if groups.isEmpty && !isLoading {
                ContentUnavailableView("No groups yet", systemImage: "person.3")
            }

            ForEach(groups) { group in
                NavigationLink(value: group.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                        Text("\(group.expenseCount) expenses • \(group.memberCount) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Groups")
        .navigationDestination(for: String.self) { groupId in
            GroupDetailView(groupId: groupId)
        }
        .toolbar {
            Button("New group", systemImage: "plus") {
                showingCreateGroup = true
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
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
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                Picker("Currency", selection: $currency) {
                    ForEach(currencies, id: \.self, content: Text.init)
                }
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self, content: Text.init)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || isSaving)
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

