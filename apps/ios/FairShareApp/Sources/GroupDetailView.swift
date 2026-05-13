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
        PaisaScreen {
            if let group {
                GroupHero(group: group)

                PaisaPanel(tint: PaisaTheme.sky.opacity(0.38), padding: 12) {
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch selectedTab {
                case .expenses:
                    expensesSection(group)
                case .balances:
                    balancesSection(group)
                case .members:
                    membersSection(group)
                }
            } else if isLoading {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.42)) {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading group")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let errorMessage {
                PaisaEmptyState(
                    title: "Group unavailable",
                    subtitle: errorMessage,
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
        }
        .navigationTitle(group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    activeSheet = .addMember
                } label: {
                    Label("Add member", systemImage: "person.badge.plus")
                        .labelStyle(.iconOnly)
                }
                .disabled(group == nil)
                .accessibilityLabel("Add member")

                Button {
                    activeSheet = .addExpense
                } label: {
                    Label("Add expense", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .disabled(group == nil)
                .accessibilityLabel("Add expense")
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

        VStack(alignment: .leading, spacing: 12) {
            PaisaSectionHeader("Expenses", subtitle: "Group activity", systemImage: "receipt.fill")

            if expenses.isEmpty {
                PaisaEmptyState(
                    title: "No expenses yet",
                    subtitle: "Add the first shared expense for this group.",
                    systemImage: "receipt"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(expenses) { expense in
                        PaisaPanel(tint: PaisaTheme.sky.opacity(0.42), interactive: true) {
                            ExpenseActionRow(
                                expense: expense,
                                onEdit: { activeSheet = .editExpense(expense) },
                                onDelete: { Task { await delete(expense) } }
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func balancesSection(_ group: GroupDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PaisaSectionHeader("Simplified payments", subtitle: "Suggested transfers", systemImage: "arrow.triangle.branch")

            if balances?.simplifiedDebts.isEmpty ?? true {
                PaisaEmptyState(
                    title: "All settled up",
                    subtitle: "There are no suggested payments for this group.",
                    systemImage: "checkmark.circle.fill"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(balances?.simplifiedDebts ?? []) { debt in
                        PaisaPanel(tint: PaisaTheme.mint.opacity(0.44)) {
                            DebtRow(debt: debt, currency: group.currency) {
                                activeSheet = .settle(debt)
                            }
                        }
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            PaisaSectionHeader("Net balances", subtitle: "How everyone stands", systemImage: "chart.bar.fill")

            PaisaPanel(tint: PaisaTheme.blush.opacity(0.34)) {
                VStack(spacing: 12) {
                    ForEach(balances?.netBalances ?? []) { balance in
                        HStack {
                            Text(balance.name ?? "Unknown")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(FairShareFormatters.currency(balance.netAmount, code: group.currency))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(balance.netAmount < 0 ? PaisaTheme.coral : PaisaTheme.leaf)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func membersSection(_ group: GroupDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PaisaSectionHeader("Members", subtitle: "Everyone in this circle", systemImage: "person.2.fill")

            VStack(spacing: 12) {
                ForEach(group.members) { member in
                    PaisaPanel(tint: PaisaTheme.sky.opacity(0.4)) {
                        MemberRow(member: member)
                    }
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

private struct GroupHero: View {
    let group: GroupDTO

    var body: some View {
        PaisaPanel(tint: PaisaTheme.mint.opacity(0.46)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(PaisaTheme.ink)
                        if let description = group.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    PaisaPill(title: group.currency, tint: PaisaTheme.plum)
                }

                HStack(spacing: 10) {
                    PaisaPill(title: "\(group.expenseCount) expenses", tint: PaisaTheme.teal)
                    PaisaPill(title: "\(group.memberCount) members", tint: PaisaTheme.leaf)
                    PaisaPill(title: group.category.capitalized, tint: PaisaTheme.coral)
                }
            }
        }
    }
}

private struct ExpenseActionRow: View {
    let expense: ExpenseDTO
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExpenseRow(expense: expense)

            HStack(spacing: 10) {
                PaisaSecondaryButton("Edit", systemImage: "square.and.pencil", tint: PaisaTheme.teal, action: onEdit)
                PaisaSecondaryButton("Delete", systemImage: "trash", tint: PaisaTheme.coral, action: onDelete)
            }
        }
    }
}

private struct DebtRow: View {
    let debt: SimplifiedDebtDTO
    let currency: String
    let onSettle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PaisaIconBadge(systemImage: "arrow.left.arrow.right.circle.fill", tint: PaisaTheme.teal)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(debt.fromName ?? "Someone") -> \(debt.toName ?? "Someone")")
                    .font(.headline.weight(.semibold))
                Text("Suggested settlement")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(FairShareFormatters.currency(debt.amount, code: currency))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PaisaTheme.plum)
                PaisaSecondaryButton("Settle", systemImage: "checkmark.circle", tint: PaisaTheme.leaf, action: onSettle)
            }
        }
    }
}

private struct MemberRow: View {
    let member: MemberDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PaisaIconBadge(systemImage: "person.crop.circle.fill", tint: PaisaTheme.plum)

            VStack(alignment: .leading, spacing: 6) {
                Text(member.user.displayName)
                    .font(.headline.weight(.semibold))
                HStack(spacing: 8) {
                    Text(member.user.email ?? "No email")
                    Text("•")
                    Text(member.role.capitalized)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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
            PaisaScreen {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.44)) {
                    PaisaSectionHeader("Add member", subtitle: "Group access", systemImage: "person.badge.plus")
                }

                PaisaPanel(tint: PaisaTheme.mint.opacity(0.42)) {
                    PaisaFieldLabel("Email") {
                        TextField("member@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .paisaTextField()
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
                    "Add member",
                    systemImage: "person.crop.circle.badge.plus",
                    isLoading: isSaving,
                    isDisabled: email.isEmpty || isSaving
                ) {
                    Task { await save() }
                }
            }
            .navigationTitle("Add member")
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
