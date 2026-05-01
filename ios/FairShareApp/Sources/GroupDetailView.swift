import SwiftUI

struct GroupDetailView: View {
    @Environment(AuthStore.self) private var authStore
    let groupId: String

    @State private var group: GroupDTO?
    @State private var balances: GroupBalancesDTO?
    @State private var selectedTab: Tab = .expenses
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var activeSheet: Sheet?

    enum Tab: String, CaseIterable, Identifiable {
        case expenses = "Expenses"
        case balances = "Balances"
        case members = "Members"
        var id: String { rawValue }
    }

    enum Sheet: Identifiable {
        case addExpense
        case editExpense(ExpenseDTO)
        case addMember
        case settle(SimplifiedDebtDTO)

        var id: String {
            switch self {
            case .addExpense: "addExpense"
            case .editExpense(let expense): "edit-\(expense.id)"
            case .addMember: "addMember"
            case .settle(let debt): "settle-\(debt.id)"
            }
        }
    }

    var body: some View {
        List {
            if let group {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.largeTitle.bold())
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(group.expenseCount) expenses • \(group.memberCount) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .expenses:
                    expensesSection(group)
                case .balances:
                    balancesSection(group)
                case .members:
                    membersSection(group)
                }
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Add member", systemImage: "person.badge.plus") {
                    activeSheet = .addMember
                }
                .disabled(group == nil)
                Button("Add expense", systemImage: "plus") {
                    activeSheet = .addExpense
                }
                .disabled(group == nil)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addExpense:
                if let group {
                    ExpenseEditorView(group: group, expense: nil) {
                        Task { await load() }
                    }
                }
            case .editExpense(let expense):
                if let group {
                    ExpenseEditorView(group: group, expense: expense) {
                        Task { await load() }
                    }
                }
            case .addMember:
                AddMemberView(groupId: groupId) {
                    Task { await load() }
                }
            case .settle(let debt):
                SettleUpView(debt: debt, currency: group?.currency ?? "INR", groupId: groupId) {
                    Task { await load() }
                }
            }
        }
    }

    @ViewBuilder
    private func expensesSection(_ group: GroupDTO) -> some View {
        let expenses = group.expenses ?? []
        Section("Expenses") {
            if expenses.isEmpty {
                ContentUnavailableView("No expenses yet", systemImage: "receipt")
            } else {
                ForEach(expenses) { expense in
                    Button {
                        activeSheet = .editExpense(expense)
                    } label: {
                        ExpenseRow(expense: expense)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            Task { await delete(expense) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func balancesSection(_ group: GroupDTO) -> some View {
        Section("Simplified payments") {
            if balances?.simplifiedDebts.isEmpty ?? true {
                ContentUnavailableView("All settled up", systemImage: "checkmark.circle")
            } else {
                ForEach(balances?.simplifiedDebts ?? []) { debt in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(debt.fromName ?? "Someone") → \(debt.toName ?? "Someone")")
                            Text("Suggested settlement")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(FairShareFormatters.currency(debt.amount, code: group.currency))
                        Button("Settle") {
                            activeSheet = .settle(debt)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }

        Section("Net balances") {
            ForEach(balances?.netBalances ?? []) { balance in
                HStack {
                    Text(balance.name ?? "Unknown")
                    Spacer()
                    Text(FairShareFormatters.currency(balance.netAmount, code: group.currency))
                        .foregroundStyle(balance.netAmount < 0 ? .red : .green)
                }
            }
        }
    }

    @ViewBuilder
    private func membersSection(_ group: GroupDTO) -> some View {
        Section("Members") {
            ForEach(group.members) { member in
                VStack(alignment: .leading) {
                    Text(member.user.displayName)
                    HStack {
                        Text(member.user.email ?? "")
                        Spacer()
                        Text(member.role.capitalized)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: GroupResponse = try await authStore.apiClient.get("/api/mobile/groups/\(groupId)")
            group = response.group
            balances = response.balances
        } catch APIError.unauthorized {
            authStore.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func delete(_ expense: ExpenseDTO) async {
        do {
            let _: SuccessResponse = try await authStore.apiClient.delete("/api/mobile/expenses/\(expense.id)")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore
    let groupId: String
    let onSaved: () -> Void

    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Add member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task { await save() }
                    }
                    .disabled(email.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let _: MemberResponse = try await authStore.apiClient.post(
                "/api/mobile/groups/\(groupId)/members",
                body: AddMemberRequest(email: email)
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
