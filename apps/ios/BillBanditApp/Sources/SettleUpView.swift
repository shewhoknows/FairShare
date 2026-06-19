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
            PaisaScreen {
                PaisaPanel(tint: PaisaTheme.mint.opacity(0.46)) {
                    VStack(alignment: .leading, spacing: 12) {
                        PaisaSectionHeader("Settle up", subtitle: "Record a clean payment", systemImage: "checkmark.circle.fill")
                        Text("\(debt.fromName ?? "Someone") pays \(debt.toName ?? "Someone")")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PaisaTheme.ink)
                    }
                }

                PaisaPanel(tint: PaisaTheme.sky.opacity(0.42)) {
                    VStack(alignment: .leading, spacing: 16) {
                        PaisaFieldLabel("Amount") {
                            TextField("Amount", text: $amount)
                                .keyboardType(.decimalPad)
                                .paisaTextField()
                        }

                        PaisaFieldLabel("Note") {
                            TextField("Optional note", text: $note)
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
                    "Save payment",
                    systemImage: "checkmark.circle.fill",
                    isLoading: isSaving,
                    isDisabled: (Double(amount) ?? 0) <= 0 || isSaving
                ) {
                    Task { await save() }
                }
            }
            .navigationTitle("Settle up")
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
