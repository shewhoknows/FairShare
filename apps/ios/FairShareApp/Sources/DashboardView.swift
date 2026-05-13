import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var dashboard: DashboardResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var activeSheet: Sheet?

    enum Sheet: Identifiable {
        case settle(BalanceDTO)
        case chooseExpenseGroup([GroupDTO])
        case addExpense(GroupDTO)

        var id: String {
            switch self {
            case .settle(let balance):
                "settle-\(balance.id)"
            case .chooseExpenseGroup:
                "choose-expense-group"
            case .addExpense(let group):
                "add-expense-\(group.id)"
            }
        }
    }

    var body: some View {
        PaisaScreen {
            if let dashboard {
                DashboardHero(
                    displayName: currentUserName,
                    netBalance: dashboard.totalOwed - dashboard.totalOwe,
                    currency: dashboard.currency,
                    canCreateExpense: !dashboard.groups.isEmpty,
                    onCreateExpense: { createExpense(from: dashboard.groups) }
                )
                .accessibilityIdentifier("dashboard.title")

                PaisaGlassGroup(spacing: 14) {
                    HStack(spacing: 12) {
                        PaisaMetricTile(
                            title: "Balance",
                            amount: FairShareFormatters.currency(dashboard.totalOwed - dashboard.totalOwe, code: dashboard.currency),
                            tone: dashboard.totalOwed >= dashboard.totalOwe ? PaisaTheme.leaf : PaisaTheme.coral
                        )
                        PaisaMetricTile(
                            title: "Owed",
                            amount: FairShareFormatters.currency(dashboard.totalOwed, code: dashboard.currency),
                            tone: PaisaTheme.leaf
                        )
                        PaisaMetricTile(
                            title: "Owe",
                            amount: FairShareFormatters.currency(dashboard.totalOwe, code: dashboard.currency),
                            tone: PaisaTheme.coral
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    PaisaSectionHeader("Balances", subtitle: "What needs attention right now", systemImage: "arrow.left.arrow.right.circle.fill")

                    if dashboard.balances.isEmpty {
                        PaisaEmptyState(
                            title: "All settled up",
                            subtitle: "There is nothing pending between you and your circles.",
                            systemImage: "checkmark.circle.fill"
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dashboard.balances) { balance in
                                PaisaPanel(tint: balance.amount > 0 ? PaisaTheme.mint.opacity(0.44) : PaisaTheme.blush.opacity(0.46)) {
                                    BalanceRow(balance: balance, currency: dashboard.currency) {
                                        activeSheet = .settle(balance)
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    PaisaSectionHeader("Recent expenses", subtitle: "Latest activity", systemImage: "receipt.fill")

                    if dashboard.recentExpenses.isEmpty {
                        PaisaEmptyState(
                            title: "No expenses yet",
                            subtitle: "New activity will land here once a group starts spending.",
                            systemImage: "receipt"
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dashboard.recentExpenses) { expense in
                                PaisaPanel(tint: PaisaTheme.sky.opacity(0.42)) {
                                    ExpenseRow(expense: expense)
                                }
                            }
                        }
                    }
                }
            } else if isLoading {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.42)) {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Refreshing dashboard")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let errorMessage {
                PaisaEmptyState(
                    title: "Dashboard unavailable",
                    subtitle: errorMessage,
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            Button {
                Task { await load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Refresh dashboard")
        }
        .task { await load() }
        .refreshable { await load() }
        .accessibilityIdentifier("dashboard.screen")
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settle(let balance):
                SettleUpView(
                    debt: SimplifiedDebtDTO(
                        fromId: balance.amount < 0 ? currentUserId : balance.user.id,
                        toId: balance.amount < 0 ? balance.user.id : currentUserId,
                        amount: abs(balance.amount),
                        fromName: balance.amount < 0 ? "You" : balance.user.displayName,
                        toName: balance.amount < 0 ? balance.user.displayName : "You"
                    ),
                    currency: dashboard?.currency ?? "INR",
                    groupId: nil
                ) {
                    Task { await load() }
                }
            case .chooseExpenseGroup(let groups):
                ExpenseGroupPickerView(groups: groups) { group in
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .addExpense(group)
                    }
                }
            case .addExpense(let group):
                ExpenseEditorView(group: group, expense: nil) {
                    Task { await load() }
                }
            }
        }
    }

    private var currentUserId: String {
        if case .signedIn(let user) = authStore.state { return user.id }
        return ""
    }

    private var currentUserName: String {
        if case .signedIn(let user) = authStore.state { return user.displayName }
        return "You"
    }

    private func createExpense(from groups: [GroupDTO]) {
        guard !groups.isEmpty else { return }
        if let onlyGroup = groups.onlyElement {
            activeSheet = .addExpense(onlyGroup)
        } else {
            activeSheet = .chooseExpenseGroup(groups)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            dashboard = try await authStore.apiClient.get("/api/mobile/dashboard")
        } catch APIError.unauthorized {
            authStore.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct DashboardHero: View {
    let displayName: String
    let netBalance: Double
    let currency: String
    let canCreateExpense: Bool
    let onCreateExpense: () -> Void

    var body: some View {
        PaisaPanel(tint: netBalance >= 0 ? PaisaTheme.mint.opacity(0.5) : PaisaTheme.blush.opacity(0.5)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hello, \(displayName)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PaisaTheme.ink)
                        Text(netBalance >= 0 ? "You are ahead overall." : "You have payments to settle.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PaisaIconBadge(
                        systemImage: netBalance >= 0 ? "sparkles" : "arrow.up.right.circle.fill",
                        tint: netBalance >= 0 ? PaisaTheme.leaf : PaisaTheme.coral
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Net balance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(FairShareFormatters.currency(netBalance, code: currency))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(netBalance >= 0 ? PaisaTheme.leaf : PaisaTheme.coral)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                PaisaPrimaryButton(
                    "New expense",
                    systemImage: "plus.circle.fill",
                    isDisabled: !canCreateExpense,
                    action: onCreateExpense
                )
                .accessibilityIdentifier("dashboard.new-expense")
            }
        }
    }
}

private struct ExpenseGroupPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let groups: [GroupDTO]
    let onSelect: (GroupDTO) -> Void

    var body: some View {
        NavigationStack {
            PaisaScreen {
                PaisaPanel(tint: PaisaTheme.sky.opacity(0.45)) {
                    PaisaSectionHeader("New expense", subtitle: "Choose a group", systemImage: "plus.circle.fill")
                }

                VStack(spacing: 12) {
                    ForEach(groups) { group in
                        Button {
                            onSelect(group)
                            dismiss()
                        } label: {
                            PaisaPanel(tint: PaisaTheme.mint.opacity(0.42), interactive: true) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.name)
                                            .font(.headline.weight(.semibold))
                                        Text("\(group.memberCount) members • \(group.currency)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose group")
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
}

struct BalanceRow: View {
    let balance: BalanceDTO
    let currency: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PaisaIconBadge(
                systemImage: balance.amount > 0 ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill",
                tint: balance.amount > 0 ? PaisaTheme.leaf : PaisaTheme.coral
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(balance.user.displayName)
                    .font(.headline.weight(.semibold))
                Text(balance.amount > 0 ? "owes you" : "you owe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(FairShareFormatters.currency(abs(balance.amount), code: currency))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(balance.amount > 0 ? PaisaTheme.leaf : PaisaTheme.coral)
                PaisaSecondaryButton(
                    balance.amount > 0 ? "Received" : "Settle",
                    systemImage: balance.amount > 0 ? "checkmark.circle" : "arrow.left.arrow.right.circle",
                    tint: balance.amount > 0 ? PaisaTheme.leaf : PaisaTheme.teal,
                    action: action
                )
            }
        }
    }
}

struct ExpenseRow: View {
    let expense: ExpenseDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PaisaIconBadge(systemImage: "receipt.fill", tint: PaisaTheme.sun)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(expense.description)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PaisaTheme.ink)
                    Spacer()
                    Text(FairShareFormatters.currency(expense.amount, code: expense.currency))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PaisaTheme.plum)
                }

                HStack(spacing: 8) {
                    Text("Paid by \(expense.paidBy?.displayName ?? "Unknown")")
                    Text("•")
                    Text(FairShareFormatters.day(expense.date))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
