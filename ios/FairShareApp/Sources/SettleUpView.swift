import SwiftUI

struct SettleUpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthStore.self) private var authStore

    let debt: SimplifiedDebtDTO
    let currency: String
    let groupId: String?
    let onSaved: () -> Void

    @State private var amount: String
    @State private var note = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(debt: SimplifiedDebtDTO, currency: String, groupId: String?, onSaved: @escaping () -> Void) {
        self.debt = debt
        self.currency = currency
        self.groupId = groupId
        self.onSaved = onSaved
        _amount = State(initialValue: String(format: "%.2f", debt.amount))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment") {
                    Text("\(debt.fromName ?? "Someone") pays \(debt.toName ?? "Someone")")
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Note", text: $note)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Settle up")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled((Double(amount) ?? 0) <= 0 || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let value = Double(amount), value > 0 else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let currentUserId: String
            if case .signedIn(let user) = authStore.state {
                currentUserId = user.id
            } else {
                return
            }

            let body = CreateTransactionRequest(
                receiverId: debt.fromId == currentUserId ? debt.toId : nil,
                senderId: debt.toId == currentUserId ? debt.fromId : nil,
                amount: value,
                currency: currency,
                groupId: groupId,
                note: note.isEmpty ? nil : note
            )
            let _: TransactionResponse = try await authStore.apiClient.post("/api/mobile/transactions", body: body)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

