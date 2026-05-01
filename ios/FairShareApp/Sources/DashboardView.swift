import SwiftUI

struct DashboardView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var dashboard: DashboardResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var settleDebt: BalanceDTO?

    var body: some View {
        List {
            if let dashboard {
                Section {
                    HStack {
                        BalanceMetric(
                            title: "Balance",
                            amount: dashboard.totalOwed - dashboard.totalOwe,
                            currency: dashboard.currency
                        )
                        BalanceMetric(title: "Owed", amount: dashboard.totalOwed, currency: dashboard.currency)
                        BalanceMetric(title: "Owe", amount: dashboard.totalOwe, currency: dashboard.currency)
                    }
                }

                Section("Balances") {
                    if dashboard.balances.isEmpty {
                        ContentUnavailableView("No balances yet", systemImage: "checkmark.circle")
                    } else {
                        ForEach(dashboard.balances) { balance in
                            BalanceRow(balance: balance, currency: dashboard.currency) {
                                settleDebt = balance
                            }
                        }
                    }
                }

                Section("Recent expenses") {
                    if dashboard.recentExpenses.isEmpty {
                        ContentUnavailableView("No expenses yet", systemImage: "receipt")
                    } else {
                        ForEach(dashboard.recentExpenses) { expense in
                            ExpenseRow(expense: expense)
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Dashboard")
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await load() }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $settleDebt) { balance in
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
        }
    }

    private var currentUserId: String {
        if case .signedIn(let user) = authStore.state { return user.id }
        return ""
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

struct BalanceMetric: View {
    let title: String
    let amount: Double
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(FairShareFormatters.currency(amount, code: currency))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(amount < 0 ? .red : .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BalanceRow: View {
    let balance: BalanceDTO
    let currency: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(balance.user.displayName)
                Text(balance.amount > 0 ? "owes you" : "you owe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(FairShareFormatters.currency(abs(balance.amount), code: currency))
                .foregroundStyle(balance.amount > 0 ? .green : .red)
            Button(balance.amount > 0 ? "Received" : "Settle", action: action)
                .buttonStyle(.bordered)
        }
    }
}

struct ExpenseRow: View {
    let expense: ExpenseDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(expense.description)
                    .font(.headline)
                Spacer()
                Text(FairShareFormatters.currency(expense.amount, code: expense.currency))
                    .font(.subheadline.weight(.semibold))
            }
            HStack {
                Text("Paid by \(expense.paidBy?.displayName ?? "Unknown")")
                Spacer()
                Text(FairShareFormatters.day(expense.date))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

